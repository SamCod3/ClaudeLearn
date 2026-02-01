#!/bin/bash
#
# migrate-all-projects.sh - Migración masiva de proyectos a sistema de backup
#
# Uso: migrate-all-projects.sh [--dry-run] [--project NAME] [--force]
#
# Opciones:
#   --dry-run        Preview sin cambios
#   --project NAME   Migrar solo proyecto específico
#   --force          Reindexar sesiones existentes
#
# Este script:
# 1. Escanea ~/.claude/projects/
# 2. Decodifica paths encoded correctamente
# 3. Copia .jsonl a ~/.claude-backup/{project}/{session_id}.jsonl
# 4. Genera metadata desde transcript oficial
# 5. Indexa en SQLite FTS5

set -euo pipefail

# ============================================================================
# Configuración
# ============================================================================

PROJECTS_DIR="$HOME/.claude/projects"
BACKUP_DIR="$HOME/.claude-backup"
DB_PATH="$BACKUP_DIR/sessions.db"
INDEX_SCRIPT="$HOME/.claude/hooks/index-session.sh"

DRY_RUN=false
FORCE=false
SPECIFIC_PROJECT=""

# Contadores
TOTAL_PROJECTS=0
TOTAL_SESSIONS=0
MIGRATED_SESSIONS=0
SKIPPED_SESSIONS=0
ERRORS=0
TOTAL_SIZE=0

# ============================================================================
# Funciones auxiliares
# ============================================================================

log_info() {
  echo "ℹ️  $*"
}

log_success() {
  echo "✓ $*"
}

log_warning() {
  echo "⚠️  $*"
}

log_error() {
  echo "❌ $*" >&2
  ERRORS=$((ERRORS + 1))
}

# Decodificar path encoded correctamente
decode_project_path() {
  local encoded="$1"  # -Users-sambler-DEV-ANTIGRAVITY-android-alldebrid

  # Método 1: Leer cwd del primer mensaje user en .jsonl (más confiable)
  local first_jsonl
  first_jsonl=$(find "$PROJECTS_DIR/$encoded" -name "*.jsonl" -type f 2>/dev/null | head -1)

  if [ -n "$first_jsonl" ] && [ -f "$first_jsonl" ]; then
    local cwd
    cwd=$(jq -r 'select(.type=="user") | .cwd // empty' "$first_jsonl" 2>/dev/null | grep -v '^$' | head -1)

    if [ -n "$cwd" ]; then
      basename "$cwd"
      return
    fi
  fi

  # Método 2: Decodificar path completo
  local decoded_path="/${encoded#-}"
  decoded_path="${decoded_path//-/\/}"  # Reemplazar - por /

  # Si path existe, usar basename
  if [ -d "$decoded_path" ]; then
    basename "$decoded_path"
    return
  fi

  # Fallback: último segmento del encoded
  echo "${encoded##*-}"
}

# Formatear tamaño (compatible macOS)
format_size() {
  local bytes="$1"

  if [ "$bytes" -lt 1024 ]; then
    echo "${bytes}B"
  elif [ "$bytes" -lt 1048576 ]; then
    echo "$((bytes / 1024))KB"
  else
    echo "$((bytes / 1048576))MB"
  fi
}

# Extraer metadata desde transcript oficial
extract_metadata_from_jsonl() {
  local jsonl_path="$1"
  local session_id="$2"

  # Buscar en mensajes user (más confiable)
  local timestamp
  timestamp=$(jq -r 'select(.type=="user") | .timestamp // empty' "$jsonl_path" 2>/dev/null | grep -v '^$' | head -1)

  local cwd
  cwd=$(jq -r 'select(.type=="user") | .cwd // empty' "$jsonl_path" 2>/dev/null | grep -v '^$' | head -1)

  local git_branch
  git_branch=$(jq -r 'select(.type=="user") | .gitBranch // empty' "$jsonl_path" 2>/dev/null | grep -v '^$' | head -1)

  # Edited files desde trackedFileBackups
  local edited_files
  edited_files=$(jq -r '
    select(.type=="file-history-snapshot") |
    .trackedFileBackups // {} |
    keys[]
  ' "$jsonl_path" 2>/dev/null | sort -u | jq -R -s 'split("\n") | map(select(. != ""))')

  # Last user message
  local last_user_msg
  last_user_msg=$(jq -r '
    select(.type=="user") |
    .message.content |
    if type == "array" then
      if .[0].type == "text" then .[0].text
      elif .[0].text then .[0].text
      else . end
    else . end
  ' "$jsonl_path" 2>/dev/null | grep -v "^$" | tail -1 | head -c 500)

  # Generar JSON de metadata
  local project
  project=$(basename "$cwd")

  local timestamp_end
  timestamp_end=$(jq -r 'select(.timestamp) | .timestamp' "$jsonl_path" 2>/dev/null | tail -1)

  jq -n \
    --arg session_id "$session_id" \
    --arg project "$project" \
    --arg cwd "$cwd" \
    --arg timestamp_start "$timestamp" \
    --arg timestamp_end "$timestamp_end" \
    --arg git_branch "$git_branch" \
    --arg last_topic "$last_user_msg" \
    --argjson edited_files "$edited_files" \
    '{
      session_id: $session_id,
      project: $project,
      cwd: $cwd,
      timestamp_start: $timestamp_start,
      timestamp_end: $timestamp_end,
      git_branch: $git_branch,
      edited_files: $edited_files,
      last_topic: $last_topic
    }'
}

# Migrar un proyecto
migrate_project() {
  local encoded_dir="$1"
  local project_name="$2"

  log_info "Migrando proyecto: $project_name"

  local project_backup_dir="$BACKUP_DIR/$project_name"

  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$project_backup_dir"
  fi

  local session_count=0
  local migrated_count=0

  # Procesar cada .jsonl en el directorio
  while IFS= read -r jsonl_file; do
    [ -f "$jsonl_file" ] || continue

    session_count=$((session_count + 1))

    local session_id
    session_id=$(basename "$jsonl_file" .jsonl)

    local backup_jsonl="$project_backup_dir/${session_id}.jsonl"
    local backup_meta="$project_backup_dir/${session_id}.json"

    # Skip si ya existe (a menos que --force)
    if [ -f "$backup_jsonl" ] && [ "$FORCE" = false ]; then
      SKIPPED_SESSIONS=$((SKIPPED_SESSIONS + 1))
      continue
    fi

    # Obtener tamaño
    local size
    size=$(stat -f%z "$jsonl_file" 2>/dev/null || echo 0)
    TOTAL_SIZE=$((TOTAL_SIZE + size))

    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY] $session_id ($(format_size $size))"
    else
      # Copiar .jsonl
      cp "$jsonl_file" "$backup_jsonl"

      # Extraer y guardar metadata
      if extract_metadata_from_jsonl "$jsonl_file" "$session_id" > "$backup_meta" 2>/dev/null; then
        log_success "  $session_id → Copiado ($(format_size $size))"

        # Indexar en FTS5
        if [ -x "$INDEX_SCRIPT" ]; then
          "$INDEX_SCRIPT" "$session_id" "$project_name" "$backup_jsonl" 2>/dev/null || log_warning "    Indexado falló"
        fi

        migrated_count=$((migrated_count + 1))
        MIGRATED_SESSIONS=$((MIGRATED_SESSIONS + 1))
      else
        log_error "  $session_id → Error extrayendo metadata"
      fi
    fi
  done < <(find "$encoded_dir" -name "*.jsonl" -type f 2>/dev/null)

  TOTAL_SESSIONS=$((TOTAL_SESSIONS + session_count))

  if [ "$DRY_RUN" = false ]; then
    echo "  ✓ Completado: $migrated_count/$session_count sesiones migradas"
  fi
}

# ============================================================================
# Main
# ============================================================================

# Parse argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --project)
      SPECIFIC_PROJECT="$2"
      shift 2
      ;;
    *)
      echo "Opción desconocida: $1"
      exit 1
      ;;
  esac
done

# Banner
echo "═══════════════════════════════════════════════════════════"
echo "  Migración Masiva de Proyectos a Sistema de Backup"
if [ "$DRY_RUN" = true ]; then
  echo "  [MODO DRY-RUN - Sin cambios reales]"
fi
echo "═══════════════════════════════════════════════════════════"
echo

# Verificar que existen los directorios necesarios
if [ ! -d "$PROJECTS_DIR" ]; then
  log_error "Directorio $PROJECTS_DIR no existe"
  exit 1
fi

# Crear estructura de backup
if [ "$DRY_RUN" = false ]; then
  mkdir -p "$BACKUP_DIR"
fi

# Escanear proyectos
log_info "Escaneando $PROJECTS_DIR..."
echo

# Contar y listar proyectos primero
while IFS= read -r encoded_dir; do
  [ -d "$encoded_dir" ] || continue

  encoded=$(basename "$encoded_dir")
  project_name=$(decode_project_path "$encoded")

  # Skip si no es el proyecto específico (si se especificó)
  if [ -n "$SPECIFIC_PROJECT" ] && [ "$project_name" != "$SPECIFIC_PROJECT" ]; then
    continue
  fi

  TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
done < <(find "$PROJECTS_DIR" -maxdepth 1 -type d -name "-*")

if [ $TOTAL_PROJECTS -eq 0 ]; then
  log_warning "No se encontraron proyectos para migrar"
  exit 0
fi

echo "Proyectos encontrados: $TOTAL_PROJECTS"
echo

# Migrar cada proyecto
while IFS= read -r encoded_dir; do
  [ -d "$encoded_dir" ] || continue

  encoded=$(basename "$encoded_dir")
  project_name=$(decode_project_path "$encoded")

  # Skip si no es el proyecto específico (si se especificó)
  if [ -n "$SPECIFIC_PROJECT" ] && [ "$project_name" != "$SPECIFIC_PROJECT" ]; then
    continue
  fi

  migrate_project "$encoded_dir" "$project_name"
  echo
done < <(find "$PROJECTS_DIR" -maxdepth 1 -type d -name "-*")

# Corregir nombres de proyectos mal decodificados
if [ "$DRY_RUN" = false ]; then
  log_info "Verificando nombres de proyectos..."
  echo

  RENAMED_COUNT=0

  for dir in "$BACKUP_DIR"/*/; do
    [ -d "$dir" ] || continue

    dir_name=$(basename "$dir")

    # Skip sessions.db si existe como directorio (no debería)
    [ "$dir_name" = "sessions.db" ] && continue

    # Buscar primer metadata con nombre
    first_meta=$(find "$dir" -name "*.json" -type f 2>/dev/null | head -1)

    if [ -f "$first_meta" ]; then
      real_project=$(jq -r '.project // empty' "$first_meta" 2>/dev/null)

      if [ -n "$real_project" ] && [ "$real_project" != "$dir_name" ]; then
        log_warning "Corrigiendo nombre: $dir_name → $real_project"

        # Renombrar directorio
        mv "$dir" "$BACKUP_DIR/$real_project" 2>/dev/null

        # Actualizar base de datos FTS5
        if [ -f "$DB_PATH" ]; then
          sqlite3 "$DB_PATH" <<EOF
UPDATE sessions_fts
SET project = '$real_project'
WHERE project = '$dir_name';
EOF
        fi

        RENAMED_COUNT=$((RENAMED_COUNT + 1))
      fi
    fi
  done

  if [ $RENAMED_COUNT -gt 0 ]; then
    log_success "Corregidos $RENAMED_COUNT nombres de proyectos"
    echo
  fi
fi

# Reporte final
echo "═══════════════════════════════════════════════════════════"
echo "  Migración Completa"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Proyectos procesados:   $TOTAL_PROJECTS"
echo "Sesiones encontradas:   $TOTAL_SESSIONS"

if [ "$DRY_RUN" = false ]; then
  echo "Sesiones migradas:      $MIGRATED_SESSIONS"
  echo "Sesiones omitidas:      $SKIPPED_SESSIONS"
  [ $RENAMED_COUNT -gt 0 ] && echo "Proyectos renombrados:  $RENAMED_COUNT"
  echo "Errores:                $ERRORS"
  echo "Tamaño total:           $(format_size $TOTAL_SIZE)"
  echo

  if [ -f "$DB_PATH" ]; then
    indexed_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sessions_fts;" 2>/dev/null || echo "0")
    echo "Sesiones indexadas FTS5: $indexed_count"
  fi

  echo
  echo "Para buscar: /search-sessions <query>"
  echo "Para ver sesiones: /continue-dev"
else
  echo
  echo "Ejecuta sin --dry-run para realizar la migración"
fi
echo
