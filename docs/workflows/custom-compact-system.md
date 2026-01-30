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

## Archivos relacionados

- `~/.claude/statusline.sh` - Script de statusline
- `~/.claude/hooks/token-warning.sh` - Aviso de tokens
- `~/.claude/hooks/pre-compact-backup.sh` - Backup antes de compact
- `~/.claude/skills/smart-compact/SKILL.md` - Generador de prompts
- `~/.claude/backups/` - Directorio de backups
