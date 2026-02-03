---
name: continue-dev
description: Cargar contexto de sesión anterior del proyecto actual
allowed-tools: Read, Bash, Glob
---

Listar sesiones anteriores del proyecto actual CON FECHA Y HORA en una tabla clara, permitiendo al usuario elegir cuál cargar.

**IMPORTANTE: El skill SIEMPRE ejecuta Paso 1 PRIMERO (muestra la tabla completa) ANTES de hacer preguntas.**

## Paso 1: Obtener y mostrar tabla de sesiones (PRIMERO)

**Este es el PRIMER paso y es OBLIGATORIO - se ejecuta ANTES de hacer preguntas.**

El skill ejecuta este comando para listar las sesiones desde backups y mostrar una tabla con FECHA/HORA:

```bash
PROJECT_NAME=$(basename "$PWD")
BACKUP_DIR="$HOME/.claude-backup/$PROJECT_NAME"

# Crear directorio si no existe
mkdir -p "$BACKUP_DIR"

# Verificar si hay sesiones
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(/bin/ls "$BACKUP_DIR"/*.jsonl 2>/dev/null)" ]; then
  echo "No hay backups de sesiones para este proyecto"
  echo "El sistema de backup se activará en la próxima sesión"
  exit 0
fi

# Variables para totales
TOTAL_SIZE=0
TOTAL_COUNT=0

# Listar sesiones finalizadas (excluir current-session.jsonl)
for f in $(/bin/ls -t "$BACKUP_DIR"/*.jsonl 2>/dev/null | grep -v "current-session.jsonl"); do
  [ -f "$f" ] || continue
  id=$(basename "$f" .jsonl)

  # Tamaño del .jsonl (stat es instantáneo)
  SIZE_BYTES=$(stat -f "%z" "$f" 2>/dev/null || echo 0)
  SIZE_KB=$((SIZE_BYTES / 1024))

  # Warning según tamaño
  if [ $SIZE_KB -gt 5120 ]; then
    SIZE_WARN="🔴"
    SIZE_HUMAN="$((SIZE_KB / 1024)) MB"
  elif [ $SIZE_KB -gt 2048 ]; then
    SIZE_WARN="⚠️"
    SIZE_HUMAN="$((SIZE_KB / 1024)) MB"
  elif [ $SIZE_KB -gt 1024 ]; then
    SIZE_WARN="  "
    SIZE_HUMAN="$((SIZE_KB / 1024)) MB"
  else
    SIZE_WARN="  "
    SIZE_HUMAN="${SIZE_KB} KB"
  fi

  # Buscar metadata (en mismo directorio de backup)
  METADATA_FILE="$BACKUP_DIR/${id}.json"

  if [ -f "$METADATA_FILE" ]; then
    # Usar metadata (rápido, ya parseado)
    BRANCH=$(jq -r '.git_branch // "?"' "$METADATA_FILE" 2>/dev/null)
    DATE_RAW=$(jq -r '.timestamp_start // ""' "$METADATA_FILE" 2>/dev/null)
    END_RAW=$(jq -r '.timestamp_end // ""' "$METADATA_FILE" 2>/dev/null)
    FILES=$(jq -r '.edited_files[]?' "$METADATA_FILE" 2>/dev/null | xargs -I{} basename {} 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')

    # Formatear período (con timestamps inicio→fin)
    if [ -n "$DATE_RAW" ]; then
      start_date=$(echo "$DATE_RAW" | sed 's/T.*//' | awk -F- '{print $3"/"$2}')
      start_time=$(echo "$DATE_RAW" | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
      end_date=$(echo "$END_RAW" | sed 's/T.*//' | awk -F- '{print $3"/"$2}')
      end_time=$(echo "$END_RAW" | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')

      if [ "$start_date" = "$end_date" ]; then
        DATE_FMT="${start_date} ${start_time}→${end_time}"
      else
        DATE_FMT="${start_date} ${start_time}→${end_date} ${end_time}"
      fi
    else
      DATE_FMT=$(stat -f "%Sm" -t "%d/%m %H:%M" "$f" 2>/dev/null)
    fi
  else
    # Fallback: solo stat (sin parsear .jsonl)
    BRANCH="?"
    DATE_FMT=$(stat -f "%Sm" -t "%d/%m %H:%M" "$f" 2>/dev/null)
    FILES="-"
  fi

  TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  printf "%s | %7s %s | %s | [%s] | %s\n" "$id" "$SIZE_HUMAN" "$SIZE_WARN" "$DATE_FMT" "$BRANCH" "$FILES"
done

# Mostrar total
if [ $TOTAL_COUNT -gt 0 ]; then
  TOTAL_MB=$((TOTAL_SIZE / 1048576))
  echo ""
  echo "Total: $TOTAL_COUNT sesiones (${TOTAL_MB} MB)"
fi

# Mostrar sesión en progreso (current-session.jsonl)
CURRENT_FILE="$BACKUP_DIR/current-session.jsonl"
if [ -f "$CURRENT_FILE" ]; then
  CURRENT_SIZE=$(stat -f "%z" "$CURRENT_FILE" 2>/dev/null || echo 0)
  CURRENT_KB=$((CURRENT_SIZE / 1024))
  CURRENT_LINES=$(wc -l < "$CURRENT_FILE" 2>/dev/null | tr -d ' ')

  echo ""
  echo "────────────────────────────────────────────────────────"
  echo "Sesión en progreso:"
  echo "- current-session.jsonl (${CURRENT_KB} KB, $CURRENT_LINES observations)"

  # Mostrar última herramienta usada
  LAST_TOOL=$(tail -1 "$CURRENT_FILE" 2>/dev/null | jq -r '.tool_name // "?"')
  LAST_TIME=$(tail -1 "$CURRENT_FILE" 2>/dev/null | jq -r '.timestamp // ""')
  if [ -n "$LAST_TIME" ]; then
    TIME_AGO=$(echo "$LAST_TIME" | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/')
    echo "  Última herramienta: $LAST_TOOL (${TIME_AGO})"
  fi
fi
```

## Paso 2: Mostrar menú

Presenta las sesiones en formato tabla:

```
Sesiones de {proyecto}:
#   Tamaño      Fecha        Branch   Archivos
─────────────────────────────────────────────────────────
1   6 MB 🔴    01/02 15:04  [main]   SKILL.md, check.sh
2   3 MB ⚠️    01/02 15:01  [main]   APRENDIZAJE-COMPLETO.md
3   1 MB       31/01 22:12  [main]   hooks.md, chris-dunlop...
4   365 KB     01/02 15:59  [main]   -

Total: 4 sesiones (11 MB)

¿Cuál sesión quieres cargar?
```

**Leyenda warnings:**
- 🔴 >5 MB (puede causar lentitud en startup)
- ⚠️ >2 MB (considerar limpiar)

Usa AskUserQuestion para que el usuario elija.

## Paso 3: Cargar contexto

Una vez el usuario elija, carga el metadata del backup:

```bash
PROJECT_NAME=$(basename "$PWD")
BACKUP_DIR="$HOME/.claude-backup/$PROJECT_NAME"
METADATA_FILE="$BACKUP_DIR/${id}.json"

if [ -f "$METADATA_FILE" ]; then
  jq '.' "$METADATA_FILE"
else
  echo "No hay metadata para esta sesión"
  echo "Puede que sea una sesión antigua sin backup completo"
fi
```

## Paso 4: Mostrar contexto con encabezado claro

```
════════════════════════════════════════════════════════════
CONTEXTO DE SESIÓN ANTERIOR
Inicio: {timestamp_start} → Fin: {timestamp_end}
Branch: {git_branch}
Tamaño: {size} {warning si aplica}
════════════════════════════════════════════════════════════

Archivos editados:
- {archivo1}
- {archivo2}
...

Último tema: {last_topic}

════════════════════════════════════════════════════════════
FIN CONTEXTO ANTERIOR
════════════════════════════════════════════════════════════
```

## Paso 5: Ofrecer continuar

Pregunta: "¿Quieres que lea alguno de estos archivos para continuar?"

Si el usuario dice sí, lee los archivos relevantes.

## Dependencias

Este skill funciona con el sistema de backup resiliente:

**Hooks requeridos:**
- **PostToolUse:** `~/.claude/hooks/post-tool-backup.sh` (captura incremental)
- **SessionEnd:** `~/.claude/hooks/session-end-backup.sh` (finaliza + indexa)

**Storage:**
- Backups: `~/.claude-backup/{project}/*.jsonl`
- Metadata: `~/.claude-backup/{project}/*.json`
- FTS5 index: `~/.claude-backup/sessions.db`

**Ventajas vs sistema anterior:**
- ✅ Backup completo independiente de ~/.claude/projects/
- ✅ Captura resiliente (nunca pierdes datos)
- ✅ Muestra sesión en progreso (current-session.jsonl)
- ✅ Búsqueda FTS5 disponible con /search-sessions
