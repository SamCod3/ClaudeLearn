#!/bin/bash
# Guarda contexto al terminar sesión para restaurar con --resume
# Mejora: usa jq para construir JSON (evita problemas con comillas)

input=$(cat)

# Extraer datos del input
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // ""')
CWD=$(echo "$input" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "$CWD")

# Directorio de contexto
CONTEXT_DIR="$HOME/.claude/session-context"
mkdir -p "$CONTEXT_DIR"

# Solo guardar si hay transcript
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Extraer archivos editados (estructura anidada del JSONL)
    EDITED_FILES=$(jq -r '
        select(.type == "assistant")
        | .message.content[]?
        | select(.type == "tool_use" and (.name == "Write" or .name == "Edit"))
        | .input.file_path // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null | sort -u | tail -20)

    # Extraer último mensaje de texto del usuario (ignorar tool_results que son arrays)
    LAST_USER_MSG=$(jq -r '
        select(.type == "user" and (.message.content | type) == "string")
        | .message.content
    ' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | head -c 500)

    # Extraer timestamp de inicio (primer mensaje user)
    TIMESTAMP_START=$(jq -r '
        select(.type == "user")
        | .timestamp // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null | head -1)

    # Extraer gitBranch (primer mensaje user)
    GIT_BRANCH=$(jq -r '
        select(.type == "user")
        | .gitBranch // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null | head -1)

    # Construir JSON con jq (más robusto que heredoc)
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
        }' > "$CONTEXT_DIR/${PROJECT_NAME}-${SESSION_ID}.json"
fi

exit 0
