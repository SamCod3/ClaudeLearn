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

### 2. Hook `session-end-save.sh`

**Ubicación:** `~/.claude/hooks/session-end-save.sh`

Al terminar sesión guarda en `~/.claude/session-context/{proyecto}-{session_id}.json`:
- `session_id`
- `project`
- `cwd`
- `timestamp_start` (primer mensaje)
- `timestamp_end` (al salir)
- `edited_files`
- `last_topic`

## Uso práctico

### Paso 1: Invocar el skill
```bash
claude
> /continue-dev
```

### Paso 2: Seleccionar sesión
```
Sesiones de ClaudeLearn:
| # | Fecha/Hora       | Branch                    | Archivos editados            |
|---|------------------|---------------------------|------------------------------|
| 1 | 2026-01-31 16:04 | main                      | SKILL.md, session-end-save.sh|
| 2 | 2026-01-31 12:06 | feature/oh-my-claudecode  | model-router.md, CLAUDE.md   |

¿Cuál sesión quieres cargar?
```

### Paso 3: Cargar contexto
El skill muestra:
- Archivos editados en esa sesión
- Último tema de conversación
- Timestamps de inicio/fin

### Paso 4: Continuar trabajo
Puedes pedir que lea los archivos relevantes para tener contexto completo.

## Evolución arquitectónica

**Antes:** Se intentó usar hook `SessionStart` para cargar contexto automáticamente al hacer `--resume`.

**Por qué no funcionó:**
- El hook `SessionStart` se dispara en TODA sesión (nueva o resumida)
- No había forma confiable de detectar si era resume vs nueva sesión
- Cargar contexto automáticamente en sesiones nuevas era confuso

**Solución actual:** Skill invocable manualmente (`/continue-dev`)
- El usuario decide cuándo cargar contexto anterior
- Control explícito sobre qué sesión cargar
- Sin efectos secundarios en sesiones nuevas

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

## Troubleshooting

### No aparecen sesiones
**Causa:** No hay archivos `.jsonl` en el directorio del proyecto.
**Verificar:**
```bash
ls ~/.claude/projects/-Users-sambler-DEV-*/*.jsonl
```

### Session-context no existe
**Causa:** El hook `SessionEnd` no se ejecutó o falló.
**Verificar:**
1. Hook registrado en `~/.claude/settings.json`:
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
2. El hook tiene permisos de ejecución: `chmod +x ~/.claude/hooks/session-end-save.sh`
3. `jq` está instalado: `which jq`

### El skill no aparece
**Verificar:** El archivo existe en `~/.claude/skills/continue-dev/SKILL.md`

## Archivos del sistema

| Componente | Ubicación |
|------------|-----------|
| Skill | `~/.claude/skills/continue-dev/SKILL.md` |
| Hook de guardado | `~/.claude/hooks/session-end-save.sh` |
| Session context | `~/.claude/session-context/{proyecto}-{session_id}.json` |
| Sesiones (transcripts) | `~/.claude/projects/-{path-encoded}/*.jsonl` |
