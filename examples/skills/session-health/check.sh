#!/bin/bash
# Session Health Check - Monitor preventivo de sesiones
# Detecta problemas de rendimiento antes de que ocurran

set -e

# Parsear argumentos
MODE="full"  # full, cleanup, quiet, list-json, delete
DELETE_INDICES=""
if [ "$1" = "--cleanup" ]; then
  MODE="cleanup"
elif [ "$1" = "--quiet" ]; then
  MODE="quiet"
elif [ "$1" = "--list-json" ]; then
  MODE="list-json"
elif [ "$1" = "--delete" ]; then
  MODE="delete"
  DELETE_INDICES="$2"
fi

# ═══════════════════════════════════════════════════════════
# 1. OBTENER ESTADÍSTICAS
# ═══════════════════════════════════════════════════════════

get_session_stats() {
  # Obtener directorio de sesiones del proyecto actual
  CWD_ENCODED=$(echo "$PWD" | sed 's|/|-|g' | sed 's|^-||')
  PROJECT_DIR="$HOME/.claude/projects/-$CWD_ENCODED"
  PROJECT_NAME=$(basename "$PWD")

  # Verificar que existe el directorio
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "No hay sesiones para este proyecto"
    exit 0
  fi

  # Contar sesiones
  NUM_SESSIONS=$(/bin/ls -1 "$PROJECT_DIR"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')

  if [ "$NUM_SESSIONS" -eq 0 ]; then
    echo "No hay sesiones en este proyecto"
    exit 0
  fi

  # Timestamp actual (se usa en varios cálculos)
  NOW_TIMESTAMP=$(date +%s)
  # Timestamp de hoy a medianoche (para cálculo de días de calendario)
  TODAY_MIDNIGHT=$(date -j -f "%Y-%m-%d" "$(date +%Y-%m-%d)" +%s 2>/dev/null)

  # Tamaño total
  TOTAL_SIZE=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
  TOTAL_SIZE_MB=$(du -sm "$PROJECT_DIR" 2>/dev/null | cut -f1)

  # Sesión más grande
  LARGEST_SESSION=$(du -h "$PROJECT_DIR"/*.jsonl 2>/dev/null | sort -hr | head -1)
  LARGEST_SIZE=$(echo "$LARGEST_SESSION" | awk '{print $1}')
  LARGEST_PATH=$(echo "$LARGEST_SESSION" | awk '{print $2}')
  LARGEST_FILE=$(basename "$LARGEST_PATH")
  LARGEST_SIZE_MB=$(du -m "$PROJECT_DIR"/*.jsonl 2>/dev/null | sort -nr | head -1 | awk '{print $1}')

  # Fecha y días de la sesión más grande
  LARGEST_DATE=$(stat -f "%Sm" -t "%d/%m/%Y" "$LARGEST_PATH" 2>/dev/null)
  LARGEST_DATE_YYYYMMDD=$(stat -f "%Sm" -t "%Y-%m-%d" "$LARGEST_PATH" 2>/dev/null)
  LARGEST_MIDNIGHT=$(date -j -f "%Y-%m-%d" "$LARGEST_DATE_YYYYMMDD" +%s 2>/dev/null)
  LARGEST_DAYS_OLD=$(( (TODAY_MIDNIGHT - LARGEST_MIDNIGHT) / 86400 ))

  # Sesión más antigua
  OLDEST_SESSION=$(/bin/ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | tail -1)
  OLDEST_DATE=$(stat -f "%Sm" -t "%d/%m/%Y" "$OLDEST_SESSION" 2>/dev/null)
  OLDEST_DATE_YYYYMMDD=$(stat -f "%Sm" -t "%Y-%m-%d" "$OLDEST_SESSION" 2>/dev/null)

  # Días desde la sesión más antigua (usando fechas de calendario, no timestamps exactos)
  OLDEST_MIDNIGHT=$(date -j -f "%Y-%m-%d" "$OLDEST_DATE_YYYYMMDD" +%s 2>/dev/null)
  DAYS_OLD=$(( (TODAY_MIDNIGHT - OLDEST_MIDNIGHT) / 86400 ))

  # Sesiones >14 días (candidatas para limpieza según cleanupPeriodDays)
  SESSIONS_TO_CLEANUP=$(find "$PROJECT_DIR" -name "*.jsonl" -mtime +14 2>/dev/null | wc -l | tr -d ' ')

  # Leer cleanupPeriodDays de settings.json si existe
  CLEANUP_PERIOD=14
  if [ -f "$HOME/.claude/settings.json" ]; then
    CLEANUP_PERIOD=$(jq -r '.cleanupPeriodDays // 14' "$HOME/.claude/settings.json" 2>/dev/null)
  fi
}

# ═══════════════════════════════════════════════════════════
# 2. CALCULAR HEALTH SCORE
# ═══════════════════════════════════════════════════════════

calculate_health_score() {
  # RED: >25 sesiones OR >10MB total OR sesión >5MB
  if [ "$NUM_SESSIONS" -gt 25 ] || [ "$TOTAL_SIZE_MB" -gt 10 ] || [ "$LARGEST_SIZE_MB" -gt 5 ]; then
    echo "RED"
    return
  fi

  # YELLOW: >15 sesiones OR >5MB total OR sesión >2MB
  if [ "$NUM_SESSIONS" -gt 15 ] || [ "$TOTAL_SIZE_MB" -gt 5 ] || [ "$LARGEST_SIZE_MB" -gt 2 ]; then
    echo "YELLOW"
    return
  fi

  # GREEN: todo OK
  echo "GREEN"
}

# ═══════════════════════════════════════════════════════════
# 3. HELPER: PLURALIZACIÓN
# ═══════════════════════════════════════════════════════════

pluralize_days() {
  local num=$1
  if [ "$num" -eq 1 ]; then
    echo "1 día"
  else
    echo "$num días"
  fi
}

# ═══════════════════════════════════════════════════════════
# 4. MOSTRAR OUTPUT
# ═══════════════════════════════════════════════════════════

show_compact_output() {
  local health="$1"

  # Línea 1: Estado y stats básicos
  case "$health" in
    "GREEN") echo "🟢 SALUDABLE | $NUM_SESSIONS sesiones ($TOTAL_SIZE)" ;;
    "YELLOW") echo "🟡 ATENCIÓN | $NUM_SESSIONS sesiones ($TOTAL_SIZE)" ;;
    "RED") echo "🔴 PELIGRO | $NUM_SESSIONS sesiones ($TOTAL_SIZE)" ;;
  esac

  # Línea 2: Sesión más grande con fecha
  echo "   Mayor: $LARGEST_SIZE ($LARGEST_DATE, hace $(pluralize_days $LARGEST_DAYS_OLD))"

  # Línea 3: Acción si hay problema
  if [ "$health" = "RED" ] || [ "$health" = "YELLOW" ]; then
    if [ "$LARGEST_SIZE_MB" -gt 2 ] && [ "$SESSIONS_TO_CLEANUP" -eq 0 ]; then
      # Sesión grande pero reciente - no se puede compactar (bug #22107)
      echo ""
      echo "   Sesión grande reciente. Opciones:"
      echo "   • Eliminar: /session-health --cleanup"
      echo "   • Esperar cleanup automático (${CLEANUP_PERIOD} días)"
    else
      echo "   Limpiar: /session-health --cleanup"
    fi
  fi
}

show_full_output() {
  local health="$1"

  echo "📊 SESSION HEALTH - $PROJECT_NAME"
  echo ""

  case "$health" in
    "GREEN") echo "🟢 Estado: SALUDABLE" ;;
    "YELLOW") echo "🟡 Estado: ATENCIÓN" ;;
    "RED") echo "🔴 Estado: PELIGRO" ;;
  esac

  echo ""
  echo "Sesiones: $NUM_SESSIONS ($TOTAL_SIZE)"
  echo "Mayor: $LARGEST_SIZE - $LARGEST_DATE (hace $(pluralize_days $LARGEST_DAYS_OLD))"
  echo "Más antigua: $OLDEST_DATE (hace $(pluralize_days $DAYS_OLD))"
  echo "Para limpiar (>$CLEANUP_PERIOD días): $SESSIONS_TO_CLEANUP"
  echo ""

  # Acción según estado
  case "$health" in
    "GREEN")
      if [ "$DAYS_OLD" -lt "$CLEANUP_PERIOD" ]; then
        DAYS_UNTIL_CLEANUP=$((CLEANUP_PERIOD - DAYS_OLD))
        echo "✓ OK. Auto-limpieza en ~$(pluralize_days $DAYS_UNTIL_CLEANUP)"
      else
        echo "✓ OK. Auto-limpieza ejecutará pronto"
      fi
      ;;
    "YELLOW"|"RED")
      if [ "$LARGEST_SIZE_MB" -gt 2 ] && [ "$SESSIONS_TO_CLEANUP" -eq 0 ]; then
        echo "⚠ Sesión grande reciente. Opciones:"
        echo "  • Eliminar: /session-health --cleanup"
        echo "  • Esperar cleanup automático ($CLEANUP_PERIOD días)"
        echo ""
        echo "Nota: --resume tiene bug conocido (Issue #22107)"
      else
        echo "Limpiar: /session-health --cleanup"
      fi
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# 5. LIMPIEZA INTERACTIVA
# ═══════════════════════════════════════════════════════════

# Parsear selección del usuario (1,3,5 o 2-5 o 1,3-5,7)
parse_selection() {
  local input="$1"
  local max="$2"
  local result=""

  # Separar por comas
  IFS=',' read -ra parts <<< "$input"
  for part in "${parts[@]}"; do
    # Limpiar espacios
    part=$(echo "$part" | tr -d ' ')

    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      # Es un rango: 2-5
      local start="${BASH_REMATCH[1]}"
      local end="${BASH_REMATCH[2]}"
      for ((i=start; i<=end && i<=max; i++)); do
        result="$result $i"
      done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      # Es un número simple
      if [ "$part" -le "$max" ] && [ "$part" -ge 1 ]; then
        result="$result $part"
      fi
    fi
  done

  # Eliminar duplicados y ordenar
  echo "$result" | tr ' ' '\n' | sort -nu | tr '\n' ' '
}

do_cleanup() {
  echo "════════════════════════════════════════════════════════════"
  echo "🧹 LIMPIEZA DE SESIONES - $PROJECT_NAME"
  echo "════════════════════════════════════════════════════════════"
  echo ""

  # Crear archivo temporal con sesiones ordenadas por tamaño
  # Formato: linea_num|size_mb|path
  local sessions_file=$(mktemp)
  local i=1
  while IFS=$'\t' read -r size_mb path; do
    echo "$i|$size_mb|$path" >> "$sessions_file"
    ((i++))
  done < <(du -m "$PROJECT_DIR"/*.jsonl 2>/dev/null | sort -nr)

  local total_sessions=$((i - 1))

  if [ "$total_sessions" -eq 0 ]; then
    echo "No hay sesiones en este proyecto."
    rm -f "$sessions_file"
    exit 0
  fi

  local context_dir="$HOME/.claude/session-context"

  echo "📋 Sesiones disponibles (ordenadas por tamaño):"
  echo ""
  printf "  %-3s  %-8s  %-12s  %-13s  %s\n" "#" "Tamaño" "Fecha" "Hora" "Archivo"
  echo "  ─────────────────────────────────────────────────────────────"

  while IFS='|' read -r num size_mb path; do
    local size_human=$(du -h "$path" 2>/dev/null | cut -f1)
    local date=$(stat -f "%Sm" -t "%d/%m" "$path" 2>/dev/null)
    local filename=$(basename "$path")
    local session_id="${filename%.jsonl}"
    local short_name="${filename:0:20}..."

    # Buscar timestamps en session-context o .jsonl
    local time_start=""
    local time_end=""
    local context_file="$context_dir/${PROJECT_NAME}-${session_id}.json"

    if [ -f "$context_file" ]; then
      time_start=$(jq -r '.timestamp_start // ""' "$context_file" 2>/dev/null | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
      time_end=$(jq -r '.timestamp_end // ""' "$context_file" 2>/dev/null | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
    else
      time_start=$(head -5 "$path" 2>/dev/null | grep -m1 '"timestamp"' | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
      time_end=$(tail -5 "$path" 2>/dev/null | grep -m1 '"timestamp"' | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
    fi

    [ -z "$time_start" ] && time_start="?"
    [ -z "$time_end" ] && time_end="?"

    # Si son días diferentes, mostrar fecha en cada timestamp
    local date_start=""
    local date_end=""
    if [ -f "$context_file" ]; then
      date_start=$(jq -r '.timestamp_start // ""' "$context_file" 2>/dev/null | sed 's/T.*//' | sed 's/.*-//')
      date_end=$(jq -r '.timestamp_end // ""' "$context_file" 2>/dev/null | sed 's/T.*//' | sed 's/.*-//')
    fi

    local time_range=""
    if [ -n "$date_start" ] && [ -n "$date_end" ] && [ "$date_start" != "$date_end" ]; then
      # Días diferentes: mostrar dd HH:MM→dd HH:MM
      time_range="${date_start} ${time_start}→${date_end} ${time_end}"
    else
      time_range="${time_start}→${time_end}"
    fi

    printf "  %-3s  %-8s  %-12s  %-18s  %s\n" "$num" "$size_human" "$date" "$time_range" "$short_name"
  done < "$sessions_file"

  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo "Total: $total_sessions sesiones, $TOTAL_SIZE"
  echo ""
  echo "Selecciona sesiones a eliminar:"
  echo "  • Números: 1,3,5"
  echo "  • Rango: 2-5"
  echo "  • Combinar: 1,3-5,7"
  echo "  • Todas: all"
  echo "  • Cancelar: q"
  echo ""
  read -p "Selección: " selection

  # Manejar cancelación
  if [ -z "$selection" ] || [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
    echo ""
    echo "Limpieza cancelada."
    rm -f "$sessions_file"
    echo "════════════════════════════════════════════════════════════"
    exit 0
  fi

  # Manejar "all"
  local indices_to_delete=""
  if [ "$selection" = "all" ] || [ "$selection" = "ALL" ]; then
    indices_to_delete=$(seq 1 $total_sessions | tr '\n' ' ')
    echo ""
    echo "⚠️  Se eliminarán TODAS las sesiones ($total_sessions)"
    read -p "¿Estás seguro? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
      echo "Limpieza cancelada."
      rm -f "$sessions_file"
      echo "════════════════════════════════════════════════════════════"
      exit 0
    fi
  else
    indices_to_delete=$(parse_selection "$selection" "$total_sessions")
  fi

  # Contar y calcular tamaño a eliminar
  local count=0
  local total_size_to_delete=0
  for idx in $indices_to_delete; do
    local line=$(grep "^${idx}|" "$sessions_file")
    if [ -n "$line" ]; then
      ((count++))
      local size_mb=$(echo "$line" | cut -d'|' -f2)
      total_size_to_delete=$((total_size_to_delete + size_mb))
    fi
  done

  if [ "$count" -eq 0 ]; then
    echo ""
    echo "No se seleccionó ninguna sesión válida."
    rm -f "$sessions_file"
    echo "════════════════════════════════════════════════════════════"
    exit 0
  fi

  # Confirmar eliminación
  echo ""
  read -p "¿Eliminar $count sesiones (${total_size_to_delete} MB)? (s/N): " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Limpieza cancelada."
    rm -f "$sessions_file"
    echo "════════════════════════════════════════════════════════════"
    exit 0
  fi

  # Ejecutar eliminación
  echo ""
  for idx in $indices_to_delete; do
    local line=$(grep "^${idx}|" "$sessions_file")
    if [ -n "$line" ]; then
      local path=$(echo "$line" | cut -d'|' -f3)
      if [ -f "$path" ]; then
        local size=$(du -h "$path" | cut -f1)
        local name=$(basename "$path")
        rm -f "$path"
        echo "✓ Eliminada: ${name:0:30}... ($size)"
      fi
    fi
  done

  rm -f "$sessions_file"
  echo ""

  # Recalcular y mostrar nuevo health score
  get_session_stats
  HEALTH=$(calculate_health_score)

  echo "────────────────────────────────────────────────────────────"
  echo "Nuevo estado después de limpieza:"
  echo ""
  show_compact_output "$HEALTH"
  echo "════════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════
# 6. MODO LIST-JSON (para uso desde Claude con AskUserQuestion)
# ═══════════════════════════════════════════════════════════

list_sessions_json() {
  local context_dir="$HOME/.claude/session-context"

  echo "["
  local first=true
  local i=1

  while IFS=$'\t' read -r size_mb path; do
    local size_human=$(du -h "$path" 2>/dev/null | cut -f1)
    local date=$(stat -f "%Sm" -t "%d/%m/%Y" "$path" 2>/dev/null)
    local date_yyyymmdd=$(stat -f "%Sm" -t "%Y-%m-%d" "$path" 2>/dev/null)
    local file_midnight=$(date -j -f "%Y-%m-%d" "$date_yyyymmdd" +%s 2>/dev/null)
    local days_old=$(( (TODAY_MIDNIGHT - file_midnight) / 86400 ))
    local filename=$(basename "$path")
    local session_id="${filename%.jsonl}"

    # Buscar timestamps en session-context
    local time_start=""
    local time_end=""
    local context_file="$context_dir/${PROJECT_NAME}-${session_id}.json"

    if [ -f "$context_file" ]; then
      # Usar session-context (rápido)
      time_start=$(jq -r '.timestamp_start // ""' "$context_file" 2>/dev/null | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
      time_end=$(jq -r '.timestamp_end // ""' "$context_file" 2>/dev/null | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
    else
      # Fallback: parsear .jsonl (más lento)
      time_start=$(head -5 "$path" 2>/dev/null | grep -m1 '"timestamp"' | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
      time_end=$(tail -5 "$path" 2>/dev/null | grep -m1 '"timestamp"' | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
    fi

    [ -z "$time_start" ] && time_start="?"
    [ -z "$time_end" ] && time_end="?"

    # Extraer fechas para detectar si cruza días
    local date_start_raw=$(jq -r '.timestamp_start // ""' "$context_file" 2>/dev/null | sed 's/T.*//')
    local date_end_raw=$(jq -r '.timestamp_end // ""' "$context_file" 2>/dev/null | sed 's/T.*//')
    local date_start_day=$(echo "$date_start_raw" | sed 's/.*-//')
    local date_end_day=$(echo "$date_end_raw" | sed 's/.*-//')

    # Formatear time_range con fecha si son días diferentes
    local time_range=""
    if [ -n "$date_start_day" ] && [ -n "$date_end_day" ] && [ "$date_start_day" != "$date_end_day" ]; then
      time_range="${date_start_day} ${time_start}→${date_end_day} ${time_end}"
    else
      time_range="${time_start}→${time_end}"
    fi

    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi

    printf '  {"index": %d, "size": "%s", "size_mb": %d, "date": "%s", "days_old": %d, "time_range": "%s", "filename": "%s", "path": "%s"}' \
      "$i" "$size_human" "$size_mb" "$date" "$days_old" "$time_range" "$filename" "$path"

    ((i++))
  done < <(du -m "$PROJECT_DIR"/*.jsonl 2>/dev/null | sort -nr)

  echo ""
  echo "]"
}

# ═══════════════════════════════════════════════════════════
# 7. MODO DELETE (eliminar sesiones por índice)
# ═══════════════════════════════════════════════════════════

delete_by_indices() {
  local indices="$1"

  # Crear archivo temporal con sesiones
  local sessions_file=$(mktemp)
  local i=1
  while IFS=$'\t' read -r size_mb path; do
    echo "$i|$size_mb|$path" >> "$sessions_file"
    ((i++))
  done < <(du -m "$PROJECT_DIR"/*.jsonl 2>/dev/null | sort -nr)

  # Parsear índices y eliminar
  local deleted=0
  local total_deleted_mb=0

  for idx in $(echo "$indices" | tr ',' ' '); do
    local line=$(grep "^${idx}|" "$sessions_file")
    if [ -n "$line" ]; then
      local path=$(echo "$line" | cut -d'|' -f3)
      local size_mb=$(echo "$line" | cut -d'|' -f2)
      if [ -f "$path" ]; then
        local size=$(du -h "$path" | cut -f1)
        local name=$(basename "$path")
        rm -f "$path"
        echo "✓ Eliminada: ${name:0:30}... ($size)"
        ((deleted++))
        total_deleted_mb=$((total_deleted_mb + size_mb))
      fi
    fi
  done

  rm -f "$sessions_file"

  echo ""
  echo "Total eliminado: $deleted sesiones (${total_deleted_mb} MB)"

  # Mostrar nuevo estado
  get_session_stats
  HEALTH=$(calculate_health_score)
  echo ""
  show_compact_output "$HEALTH"
}

# ═══════════════════════════════════════════════════════════
# 8. MAIN
# ═══════════════════════════════════════════════════════════

main() {
  # Obtener stats primero
  get_session_stats

  # Modos especiales
  if [ "$MODE" = "list-json" ]; then
    list_sessions_json
    exit 0
  fi

  if [ "$MODE" = "delete" ]; then
    if [ -z "$DELETE_INDICES" ]; then
      echo "Error: Debes especificar índices. Ejemplo: --delete 1,3,5"
      exit 1
    fi
    delete_by_indices "$DELETE_INDICES"
    exit 0
  fi

  # Si modo cleanup, ejecutar limpieza interactiva y salir
  if [ "$MODE" = "cleanup" ]; then
    do_cleanup
    exit 0
  fi

  # Calcular health score
  HEALTH=$(calculate_health_score)

  # Mostrar output según modo
  if [ "$MODE" = "quiet" ]; then
    show_compact_output "$HEALTH"
  else
    show_full_output "$HEALTH"
  fi
}

main
