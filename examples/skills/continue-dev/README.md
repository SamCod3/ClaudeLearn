# /continue-dev

Skill para cargar contexto de sesiones anteriores cuando `--resume` no funciona.

## Archivos

| Archivo | Destino | Descripción |
|---------|---------|-------------|
| `SKILL.md` | `~/.claude/skills/continue-dev/SKILL.md` | El skill principal |
| `session-end-save.sh` | `~/.claude/hooks/session-end-save.sh` | Hook que guarda metadata al salir |

## Instalación

```bash
# 1. Copiar skill
mkdir -p ~/.claude/skills/continue-dev
cp SKILL.md ~/.claude/skills/continue-dev/

# 2. Copiar hook
cp session-end-save.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/session-end-save.sh

# 3. Configurar hook en settings.json
# Añadir a ~/.claude/settings.json:
```

```json
{
  "hooks": {
    "SessionEnd": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-end-save.sh"
      }]
    }]
  }
}
```

## Uso

```bash
claude
> /continue-dev
```

## Características

- **Warnings de tamaño:** 🔴 >5MB (peligro), ⚠️ >2MB (atención)
- **Optimizado:** No parsea .jsonl grandes, usa `stat` y session-context
- **Compatible macOS:** Usa `/bin/ls` para evitar conflictos con alias

## Output esperado

```
Sesiones de proyecto:
40ca17c2... |    5 MB 🔴 | 2026-01-31 15:46 | [main] | router.js, model-router.sh
baf9ed95... |    2 MB ⚠️ | 2026-02-01 09:13 | [main] | settings.json, check.sh
64c229df... |    1 MB    | 2026-01-31 21:12 | [main] | hooks.md

Total: 3 sesiones (8 MB)
```

## Dependencias

- `jq` para parsear JSON
- Hook `SessionEnd` para metadata completa (sin él solo muestra tamaño/fecha)
