#!/bin/bash
# Hook SessionEnd: Finaliza sesión, guarda backup e indexa en FTS5
# Versión mejorada de session-end-save.sh con backup completo

input=$(cat)

# Extraer datos del evento
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // ""')
CWD=$(echo "$input" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "$CWD")

# Directorio de backup
BACKUP_DIR="$HOME/.claude-backup/$PROJECT_NAME"
mkdir -p "$BACKUP_DIR"

CURRENT_SESSION="$BACKUP_DIR/current-session.jsonl"
FINAL_JSONL="$BACKUP_DIR/${SESSION_ID}.jsonl"
METADATA_JSON="$BACKUP_DIR/${SESSION_ID}.json"

# 1. Finalizar current-session → session_id.jsonl
if [ -f "$CURRENT_SESSION" ]; then
  mv "$CURRENT_SESSION" "$FINAL_JSONL"
fi

# 2. Si existe transcript oficial, copiarlo también (fallback doble)
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  cp "$TRANSCRIPT_PATH" "$FINAL_JSONL.official"
fi

# 3. Extraer metadata del backup (o transcript oficial como fallback)
SOURCE="${FINAL_JSONL}"
[ ! -f "$SOURCE" ] && SOURCE="${FINAL_JSONL}.official"

if [ -f "$SOURCE" ]; then
  # Extraer metadata
  TIMESTAMP_START=$(jq -r 'select(.type=="user" or .timestamp) | .timestamp // empty' "$SOURCE" 2>/dev/null | head -1)
  GIT_BRANCH=$(jq -r 'select(.type=="user" or .gitBranch) | .gitBranch // empty' "$SOURCE" 2>/dev/null | head -1)

  # Archivos editados (diferentes formatos según si es backup incremental o transcript oficial)
  EDITED_FILES=$(jq -r '
    (select(.tool_name=="Write" or .tool_name=="Edit") | .tool_input.file_path // empty),
    (select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and (.name=="Write" or .name=="Edit")) | .input.file_path // empty)
  ' "$SOURCE" 2>/dev/null | sort -u | tail -20)

  # Último mensaje de usuario
  LAST_USER_MSG=$(jq -r '
    select(.type=="user" and (.message.content | type) == "string") | .message.content
  ' "$SOURCE" 2>/dev/null | tail -1 | head -c 500)

  # Guardar metadata
  jq -n \
    --arg session_id "$SESSION_ID" \
    --arg project "$PROJECT_NAME" \
    --arg cwd "$CWD" \
    --arg timestamp_start "$TIMESTAMP_START" \
    --arg timestamp_end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg git_branch "$GIT_BRANCH" \
    --arg last_topic "$LAST_USER_MSG" \
    --argjson edited_files "$(echo "$EDITED_FILES" | jq -R -s 'split("\n") | map(select(. != ""))')" \
    '{
      session_id: $session_id,
      project: $project,
      cwd: $cwd,
      timestamp_start: $timestamp_start,
      timestamp_end: $timestamp_end,
      git_branch: $git_branch,
      edited_files: $edited_files,
      last_topic: $last_topic
    }' > "$METADATA_JSON"
fi

# 4. Indexar en SQLite FTS5
INDEX_SCRIPT="$HOME/.claude/hooks/index-session.sh"
if [ -f "$INDEX_SCRIPT" ] && [ -f "$SOURCE" ]; then
  "$INDEX_SCRIPT" "$SESSION_ID" "$PROJECT_NAME" "$SOURCE" 2>/dev/null &
fi

exit 0
