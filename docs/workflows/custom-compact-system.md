# Sistema de Compact Personalizado

Sistema para gestionar manualmente el compact de contexto, con avisos automáticos y backups.

## Por qué desactivar autocompact

Con autocompact activado, Claude reserva ~40-45K tokens (22.5%) que nunca se usan. Desactivándolo:
- Acceso al 100% del contexto (200K tokens)
- Control total sobre cuándo compactar
- Backups automáticos antes de cada compact

## Componentes

### 1. Statusline - Monitoreo visual

Muestra tokens usados/totales en tiempo real.

```bash
# ~/.claude/statusline.sh
#!/bin/bash
input=$(cat)
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
CALCULATED_TOKENS=$(echo "$USED_PCT * $CONTEXT_SIZE / 100" | bc 2>/dev/null | cut -d'.' -f1)
# ... formatear y mostrar
```

Configuración en `settings.json`:
```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh"
}
```

### 2. Hook UserPromptSubmit - Aviso de tokens

Muestra aviso cuando el contexto supera umbral (80%).

```bash
# ~/.claude/hooks/token-warning.sh
#!/bin/bash
input=$(cat)
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d'.' -f1)
THRESHOLD=80

if [ "$USED_PCT" -ge "$THRESHOLD" ]; then
    echo "⚠️  Contexto al ${USED_PCT}% - considera /smart-compact"
fi
```

Configuración:
```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/hooks/token-warning.sh"
      }
    ]
  }
]
```

### 3. Skill /smart-compact - Generador de prompts

Genera prompt optimizado para `/compact` basado en la conversación actual.

```markdown
# ~/.claude/skills/smart-compact/SKILL.md
---
name: smart-compact
description: Genera prompt optimizado para /compact
allowed-tools: Read
---

Analiza la conversación y genera:
/compact "Preservar: [lo importante]. Descartar: [lo innecesario]"
```

### 4. Hook PreCompact - Backup automático

Guarda backup de la sesión antes de cada compact manual.

```bash
# ~/.claude/hooks/pre-compact-backup.sh
#!/bin/bash
input=$(cat)
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
BACKUP_DIR="$HOME/.claude/backups"
mkdir -p "$BACKUP_DIR"

SESSION_FILE=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)

if [ -n "$SESSION_FILE" ] && [ -f "$SESSION_FILE" ]; then
    cp "$SESSION_FILE" "$BACKUP_DIR/session-$(date +%Y%m%d-%H%M%S).jsonl"
fi
```

Configuración:
```json
"PreCompact": [
  {
    "matcher": "manual",
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/hooks/pre-compact-backup.sh"
      }
    ]
  }
]
```

## Flujo de uso

```
1. Trabajas normalmente
   ↓
2. Statusline muestra tokens: (85K/200K)
   ↓
3. Al escribir mensaje, ves: "⚠️ Contexto al 82%"
   ↓
4. Ejecutas: /smart-compact
   ↓
5. Copias el prompt generado
   ↓
6. Ejecutas: /compact "Preservar: ..."
   ↓
7. Hook crea backup automático
   ↓
8. Compact ejecutado, contexto reducido
```

## Persistencia de Contexto entre Sesiones

Sistema complementario que guarda contexto al terminar sesión y lo carga al hacer `--resume`.

### Hook SessionEnd - Guardar contexto

Extrae archivos editados y último tema del transcript al salir.

```bash
# ~/.claude/hooks/session-end-save.sh
#!/bin/bash
input=$(cat)

SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // ""')
CWD=$(echo "$input" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "$CWD")

CONTEXT_DIR="$HOME/.claude/session-context"
mkdir -p "$CONTEXT_DIR"

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    EDITED_FILES=$(jq -r '
        select(.type == "assistant")
        | .message.content[]?
        | select(.type == "tool_use" and (.name == "Write" or .name == "Edit"))
        | .input.file_path // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null | sort -u | tail -20)

    LAST_USER_MSG=$(jq -r '
        select(.type == "user" and (.message.content | type) == "string")
        | .message.content
    ' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | head -c 500)

    TIMESTAMP_START=$(jq -r '
        select(.type == "user")
        | .timestamp // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null | head -1)

    jq -n \
        --arg session_id "$SESSION_ID" \
        --arg project "$PROJECT_NAME" \
        --arg cwd "$CWD" \
        --arg timestamp_start "$TIMESTAMP_START" \
        --arg timestamp_end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg last_topic "$LAST_USER_MSG" \
        --argjson edited_files "$(echo "$EDITED_FILES" | jq -R -s 'split("\n") | map(select(. != ""))')" \
        '{
            session_id: $session_id,
            project: $project,
            cwd: $cwd,
            timestamp_start: $timestamp_start,
            timestamp_end: $timestamp_end,
            edited_files: $edited_files,
            last_topic: $last_topic
        }' > "$CONTEXT_DIR/${PROJECT_NAME}-${SESSION_ID}.json"
fi
exit 0
```

### Configuración

```json
"SessionEnd": [
  {
    "hooks": [
      { "type": "command", "command": "~/.claude/hooks/session-end-save.sh" }
    ]
  }
]
```

### Cargar contexto - Skill /continue-dev

En lugar de hook SessionStart, se usa el skill `/continue-dev` para cargar contexto manualmente.
Ver [docs/cli/continue-dev.md](../cli/continue-dev.md) para detalles.

### Flujo

```
Sesión termina → SessionEnd guarda archivos editados
     ↓
~/.claude/session-context/{PROYECTO}-{SESSION_ID}.json
     ↓
Nueva sesión → /continue-dev para cargar contexto
     ↓
Claude conoce qué archivos tocaste antes
```

## Archivos relacionados

- `~/.claude/statusline.sh` - Script de statusline
- `~/.claude/hooks/token-warning.sh` - Aviso de tokens
- `~/.claude/hooks/pre-compact-backup.sh` - Backup antes de compact
- `~/.claude/hooks/session-end-save.sh` - Guardar contexto al salir
- `~/.claude/skills/smart-compact/SKILL.md` - Generador de prompts
- `~/.claude/skills/continue-dev/SKILL.md` - Cargar contexto de sesión anterior
- `~/.claude/backups/` - Directorio de backups
- `~/.claude/session-context/` - Contextos por proyecto
