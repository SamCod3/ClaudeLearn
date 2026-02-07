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

---

## Agent Teams (experimental)

Feature que permite coordinar múltiples instancias de Claude trabajando juntas en el mismo proyecto. A diferencia de subagents (que reportan al parent), los teammates se comunican **peer-to-peer**.

### Teams vs Subagents

| Aspecto | Subagents | Agent Teams |
|---------|-----------|-------------|
| Comunicación | Solo con parent | Peer-to-peer entre teammates |
| Contexto | Propio, aislado | Propio, pero comparten task list |
| Coordinación | Parent asigna y recibe | Lead coordina, teammates colaboran |
| Visibilidad | Resultados al parent | Pueden ver trabajo de otros |
| Uso típico | Tareas paralelas independientes | Investigación colaborativa, debates |

### Setup

**1. Habilitar flag experimental:**
```json
// ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**2. Display modes:**

| Modo | Descripción | Cuándo usar |
|------|-------------|-------------|
| `auto` | tmux si disponible, sino in-process | Default |
| `in-process` | Todo en un terminal, switch con shortcuts | Sin tmux |
| `tmux` | Split panes, cada teammate visible | Ideal para observar |

```json
{
  "teammateMode": "tmux"
}
```

Override por sesión:
```bash
claude --teammate-mode tmux
```

**3. Instalar tmux** (para split-pane):
```bash
brew install tmux
```

iTerm2 alternativa: `brew install mkusaka/it2/it2` + habilitar Python API en iTerm2 settings.

**4. Verificar**: `/config` → debe mostrar `Teammate mode`.

### Crear un team

Describir la tarea y dejar que Claude decida la estructura:
```
Create an agent team to refactor the authentication module.
Break the work into parallel tasks.
```

O especificar teammates y modelos:
```
Create a team with 3 teammates:
- One researcher using Haiku for quick lookups
- One architect using Opus for design decisions
- Two implementers using Sonnet for code changes
```

### Navegación

**In-process mode:**
- `Shift+Tab` → Ciclar entre teammates
- Lead ve status de todos

**Split-pane mode (tmux):**
- Cada teammate en su propio pane
- Navegación estándar de tmux

### Features avanzados

#### Delegate mode
`Shift+Tab` para activar. Restringe al lead a **solo coordinación**:
- NO puede editar archivos
- NO puede ejecutar comandos
- Solo asigna tareas y sintetiza resultados

Útil cuando quieres que el lead no "haga el trabajo él mismo" en vez de delegar.

#### Plan approval
Teammates entran en modo read-only. Pueden investigar pero no modificar nada hasta que el lead aprueba su plan.

```
Spawn an architect teammate to refactor the database schema.
Require plan approval before they make any changes.
```

Criterios de aprobación:
```
Only approve plans that include test coverage.
Reject any plan that modifies the schema without a migration.
```

#### Modelos diferentes por teammate
Optimizar costo/capacidad:
- **Haiku** → research, búsquedas rápidas
- **Sonnet** → implementación de código
- **Opus** → decisiones arquitectónicas complejas

#### Pre-aprobar permisos
Los permission requests de teammates llegan al lead (fricción). Opciones:
- `/permissions` → pre-aprobar operaciones comunes
- `claude --dangerously-skip-permissions` → trust total (aplica a lead + todos los teammates)

### Hooks relevantes (v2.1.33+)

| Hook | Cuándo se dispara |
|------|-------------------|
| `TeammateIdle` | Un teammate termina y queda libre |
| `TaskCompleted` | Una tarea asignada se completa |

### Patrones de uso

#### Debugging adversarial (swarm)
Múltiples agents investigan teorías diferentes e intentan **desprobar** las de otros:
```
Spawn 5 teammates to investigate intermittent 500 errors:
1. Database connection pool exhaustion
2. Race condition in inventory reservation
3. Payment API timeout handling
4. Memory pressure / GC pauses
5. Network issues between services

Have them actively try to disprove each other's theories.
```

#### Code review paralelo
Cada reviewer aplica una lente diferente:
```
3 reviewers for PR #142:
- Security: vulnerabilities, injection, auth flaws
- Performance: bottlenecks, N+1 queries, memory
- Tests: edge cases, coverage, test quality
```

#### Feature building paralelo
Cada teammate es dueño de archivos independientes:
```
Notification system:
- Teammate 1: Backend API endpoints
- Teammate 2: Database schema + migrations
- Teammate 3: React components
- Teammate 4: WebSocket integration
- Teammate 5: Integration tests
```

### Cuándo NO usar Agent Teams

| Situación | Por qué no | Alternativa |
|-----------|------------|-------------|
| Dependencias secuenciales | Step B espera step A → no hay paralelismo | Single session |
| Ediciones al mismo archivo | Overwrites y conflictos | Single session o dividir archivo |
| Tareas simples | Overhead de coordinación > beneficio | Single agent o subagent |
| Presupuesto limitado | 5 agents ≈ 5x tokens | Subagents (más económicos) |

### Costos

Cada teammate tiene su propio context window → token usage escala linealmente con team size. Un team de 5 usa ~5x los tokens de una sesión individual.

Fuente: [Claude Code Agent Teams](https://generativeai.pub/i-tried-new-claude-code-agent-teams-and-discovered-new-way-to-swarm-45fbb61ed70b) (Joe Njenga)
