#!/bin/bash
# Script de indexado FTS5: Indexa sesión en SQLite para búsqueda
# Llamado por session-end-backup.sh al finalizar sesión

SESSION_ID="$1"
PROJECT="$2"
JSONL_PATH="$3"

# Validar inputs
if [ -z "$SESSION_ID" ] || [ -z "$PROJECT" ] || [ ! -f "$JSONL_PATH" ]; then
  exit 1
fi

DB_PATH="$HOME/.claude-backup/sessions.db"

# Crear tabla FTS5 si no existe
sqlite3 "$DB_PATH" <<EOF
CREATE VIRTUAL TABLE IF NOT EXISTS sessions_fts USING fts5(
  session_id UNINDEXED,
  project UNINDEXED,
  timestamp,
  git_branch,
  content,
  files,
  tokenize = 'porter unicode61'
);
EOF

# Extraer contenido para indexar
TIMESTAMP=$(jq -r 'select(.timestamp) | .timestamp' "$JSONL_PATH" 2>/dev/null | head -1)
GIT_BRANCH=$(jq -r 'select(.type=="user" or .gitBranch) | .gitBranch // empty' "$JSONL_PATH" 2>/dev/null | head -1)

# User messages + tool inputs (para búsqueda)
# Limitar a 50KB para evitar queries muy pesadas
CONTENT=$(jq -r '
  (select(.type=="user") | .message.content // empty),
  (select(.tool_input) | .tool_input | to_entries[] | .value // empty | tostring)
' "$JSONL_PATH" 2>/dev/null | head -c 50000)

# Files touched (con ambos formatos: backup incremental y transcript oficial)
FILES=$(jq -r '
  (select(.tool_name=="Write" or .tool_name=="Edit") | .tool_input.file_path // empty),
  (select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and (.name=="Write" or .name=="Edit")) | .input.file_path // empty)
' "$JSONL_PATH" 2>/dev/null | sort -u | tr '\n' ' ')

# Escape single quotes for SQL
CONTENT_ESCAPED=$(echo "$CONTENT" | sed "s/'/''/g")
FILES_ESCAPED=$(echo "$FILES" | sed "s/'/''/g")
GIT_BRANCH_ESCAPED=$(echo "$GIT_BRANCH" | sed "s/'/''/g")

# Insert en FTS5 (replace si existe)
sqlite3 "$DB_PATH" <<EOF
DELETE FROM sessions_fts WHERE session_id = '$SESSION_ID';
INSERT INTO sessions_fts(session_id, project, timestamp, git_branch, content, files)
VALUES (
  '$SESSION_ID',
  '$PROJECT',
  '$TIMESTAMP',
  '$GIT_BRANCH_ESCAPED',
  '$CONTENT_ESCAPED',
  '$FILES_ESCAPED'
);
EOF

exit 0
