# Subagents - Claude Code

Source: https://code.claude.com/docs/en/sub-agents

## Qué son los Subagents

Asistentes AI especializados que manejan tareas específicas. Cada subagent:
- Corre en su **propia ventana de contexto**
- Tiene su **propio system prompt**
- Puede tener **herramientas restringidas**
- Trabaja independientemente y devuelve resultados

## Por qué usar Subagents

- **Preservar contexto** - Exploración fuera de tu conversación principal
- **Aplicar restricciones** - Limitar herramientas disponibles
- **Reutilizar** - Subagents a nivel usuario disponibles en todos tus proyectos
- **Especializar** - Prompts enfocados para dominios específicos
- **Controlar costos** - Usar Haiku para tareas simples

---

## Subagents Built-in

| Agent | Modelo | Herramientas | Uso |
|-------|--------|--------------|-----|
| **Explore** | Haiku (rápido) | Solo lectura | Búsqueda en codebase |
| **Plan** | Hereda | Solo lectura | Investigación para planificar |
| **general-purpose** | Hereda | Todas | Tareas complejas multi-paso |
| **Bash** | Hereda | Bash | Comandos de terminal |

### Explore
```
"Usa Explore para encontrar dónde se maneja la autenticación"
```
Claude especifica nivel de profundidad: quick, medium, very thorough.

### Plan
Se usa en Plan Mode para investigar antes de presentar un plan.

### general-purpose
Para tareas que requieren exploración Y modificación.

---

## Crear Subagents Personalizados

### Método 1: Comando /agents (recomendado)
```
/agents
→ Create new agent
→ User-level o Project-level
→ Generate with Claude o escribir manualmente
```

### Método 2: Archivo Markdown

Ubicaciones:

| Ubicación | Alcance | Prioridad |
|-----------|---------|-----------|
| `--agents` CLI flag | Solo sesión actual | 1 (más alta) |
| `.claude/agents/` | Proyecto actual | 2 |
| `~/.claude/agents/` | Todos tus proyectos | 3 |
| Plugin `agents/` | Donde plugin está habilitado | 4 |

### Estructura del archivo

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. Analyze code and provide specific,
actionable feedback on quality, security, and best practices.
```

---

## Campos de configuración (frontmatter)

| Campo | Requerido | Descripción |
|-------|-----------|-------------|
| `name` | Sí | Identificador único (lowercase, guiones) |
| `description` | Sí | Cuándo Claude debe delegar a este agent |
| `tools` | No | Herramientas permitidas (hereda todas si omitido) |
| `disallowedTools` | No | Herramientas denegadas |
| `model` | No | `sonnet`, `opus`, `haiku`, `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `skills` | No | Skills a precargar |
| `hooks` | No | Hooks del ciclo de vida |

---

## Modelos disponibles

| Modelo | Uso recomendado |
|--------|-----------------|
| `haiku` | Tareas rápidas, búsquedas, bajo costo |
| `sonnet` | Balance entre capacidad y velocidad |
| `opus` | Tareas complejas que requieren razonamiento profundo |
| `inherit` | Usa el mismo modelo que la conversación principal |

---

## Herramientas disponibles

```
Read, Write, Edit, Bash, Glob, Grep,
WebFetch, WebSearch, Task, TodoRead, TodoWrite,
NotebookRead, NotebookEdit, AskFollowupQuestion
```

Ejemplo restringido (solo lectura):
```yaml
tools: Read, Glob, Grep
```

---

## Foreground vs Background

| Modo | Comportamiento |
|------|----------------|
| **Foreground** | Bloquea hasta completar, prompts de permisos interactivos |
| **Background** | Corre concurrentemente, permisos pre-aprobados |

```
"Ejecuta esto en background"
Ctrl+B para enviar tarea a background
```

---

## Patrones de uso

### 1. Aislar operaciones de alto volumen
```
"Usa un subagent para correr los tests y reportar solo los fallos"
```
Output verboso queda en el contexto del subagent, solo el resumen vuelve.

### 2. Research en paralelo
```
"Investiga auth, database y API en paralelo usando subagents separados"
```

### 3. Encadenar subagents
```
"Usa code-reviewer para encontrar issues, luego optimizer para arreglarlos"
```

---

## Cuándo usar cada cosa

| Usar... | Cuando... |
|---------|-----------|
| **Conversación principal** | Back-and-forth frecuente, múltiples fases comparten contexto |
| **Subagent** | Output verboso, restricciones específicas, trabajo autocontenido |
| **Skill** | Prompts reutilizables en contexto principal |

**Nota**: Los subagents NO pueden crear otros subagents.

---

## Ejemplos

### Code Reviewer (solo lectura)
```markdown
---
name: code-reviewer
description: Expert code review. Use immediately after modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code clarity and readability
- No duplicated code
- Proper error handling
- No exposed secrets
- Good test coverage

Provide feedback by priority:
- Critical (must fix)
- Warnings (should fix)
- Suggestions (consider)
```

### Debugger (puede modificar)
```markdown
---
name: debugger
description: Debugging specialist for errors and test failures.
tools: Read, Edit, Bash, Grep, Glob
---

You are an expert debugger.

When invoked:
1. Capture error and stack trace
2. Identify reproduction steps
3. Isolate failure location
4. Implement minimal fix
5. Verify solution

For each issue provide:
- Root cause explanation
- Specific code fix
- Testing approach
```

### DB Reader (con validación via hook)
```markdown
---
name: db-reader
description: Execute read-only database queries.
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---

You are a database analyst with read-only access.
Execute SELECT queries only.
```

Script de validación:
```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)\b' > /dev/null; then
  echo "Blocked: Only SELECT queries allowed" >&2
  exit 2
fi
exit 0
```

---

## Resumir subagents

Los subagents mantienen su historial. Para continuar trabajo previo:

```
"Continúa ese code review y analiza también la lógica de autorización"
```

Claude resume el subagent con contexto completo de la conversación anterior.

---

## Hooks para subagents

### En el frontmatter del subagent
```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate.sh"
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./run-linter.sh"
```

### En settings.json (nivel proyecto)
```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./setup-db.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./cleanup-db.sh" }
        ]
      }
    ]
  }
}
```

---

## Deshabilitar subagents específicos

En settings.json:
```json
{
  "permissions": {
    "deny": ["Task(Explore)", "Task(my-custom-agent)"]
  }
}
```

O via CLI:
```bash
claude --disallowedTools "Task(Explore)"
```
