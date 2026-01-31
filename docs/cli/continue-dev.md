# Sistema /continue-dev

Alternativa al `--resume` nativo cuando `sessions-index.json` está vacío/roto.

## Problema

El comando `claude --resume` no encuentra sesiones porque el archivo `~/.claude/projects/{proyecto}/sessions-index.json` tiene `entries: []` vacío, aunque los archivos `.jsonl` de las sesiones sí existen.

## Solución

### 1. Skill `/continue-dev`

**Ubicación:** `~/.claude/skills/continue-dev/SKILL.md`

Permite:
- Listar sesiones anteriores del proyecto actual
- Mostrar info distintiva: fecha, branch, archivos editados
- Cargar contexto de la sesión elegida
- Marcar claramente que es contexto anterior (con timestamps)

**Uso:**
```bash
claude
> /continue-dev

Sesiones de ClaudeLearn:
1. 31 Jan 11:06 (3h) [feature/oh-my-claudecode] - CLAUDE.md, model-router.md
2. 31 Jan 14:22 [main] - plan, SKILL.md

¿Cuál cargar? [1]
```

### 2. Hook `session-end-save.sh` (modificado)

**Ubicación:** `~/.claude/hooks/session-end-save.sh`

Al terminar sesión guarda en `~/.claude/session-context/{proyecto}-{session_id}.json`:
- `session_id`
- `project`
- `cwd`
- `timestamp_start` (primer mensaje)
- `timestamp_end` (al salir)
- `edited_files`
- `last_topic`

## Ubicaciones de datos

| Dato | Ubicación |
|------|-----------|
| Sesiones (transcripts) | `~/.claude/projects/-{path-encoded}/*.jsonl` |
| Session context | `~/.claude/session-context/{proyecto}-{session_id}.json` |
| Sessions index (roto) | `~/.claude/projects/-{path-encoded}/sessions-index.json` |

## Información extraída de cada sesión

Del `.jsonl`:
- `timestamp` de mensajes (inicio/fin)
- `gitBranch`
- Archivos editados (tool_use Write/Edit)

Del session-context (si existe):
- `last_topic`
- Timestamps verificados

## Formato de presentación

Al cargar contexto anterior se marca claramente:

```
════════════════════════════════════════════════════════════
CONTEXTO DE SESIÓN ANTERIOR
Inicio: 2026-01-31T11:06 → Fin: 2026-01-31T14:21
Branch: feature/oh-my-claudecode
════════════════════════════════════════════════════════════

Archivos editados:
- ~/.claude/hooks/model-router.sh
- docs/workflows/model-router.md
...

════════════════════════════════════════════════════════════
FIN CONTEXTO ANTERIOR
════════════════════════════════════════════════════════════
```
