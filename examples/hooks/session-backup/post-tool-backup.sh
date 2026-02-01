#!/bin/bash
# Hook PostToolUse: Captura incremental de tool executions
# Se dispara después de cada herramienta (Read, Write, Bash, etc.)
# Append a current-session.jsonl para backup resiliente

input=$(cat)

# Extraer datos del evento
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // ""')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
CWD=$(echo "$input" | jq -r '.cwd // ""')

# Skip list: herramientas low-value que no queremos capturar
SKIP_TOOLS=("AskUserQuestion" "TodoWrite" "TaskCreate" "TaskUpdate" "TaskGet" "TaskList")

for skip in "${SKIP_TOOLS[@]}"; do
  if [ "$TOOL_NAME" = "$skip" ]; then
    exit 0  # Skip silently
  fi
done

# Determinar nombre del proyecto
PROJECT_NAME=$(basename "$CWD")
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="unknown"

# Crear directorio de backup
BACKUP_DIR="$HOME/.claude-backup/$PROJECT_NAME"
mkdir -p "$BACKUP_DIR"

CURRENT_SESSION="$BACKUP_DIR/current-session.jsonl"

# Append observation en formato JSONL
# Truncar tool_output a 1000 chars para evitar archivos gigantes
echo "$input" | jq -c '{
  timestamp,
  session_id,
  tool_name,
  tool_input,
  tool_output: (if .tool_output then (.tool_output | tostring | .[0:1000]) else null end)
}' >> "$CURRENT_SESSION" 2>/dev/null

exit 0
