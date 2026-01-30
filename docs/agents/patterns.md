# Patrones y Templates de Subagents - Claude Code

Source: Patrones derivados de uso práctico y artículo "17 Claude Code SubAgents Examples"

---

## Tipos de Especialización

Hay dos enfoques para crear asistentes especializados:

### 1. Skills con Rol (contexto compartido)

Skills que definen un rol experto con instrucciones detalladas. Corren en el **mismo contexto** que la conversación principal.

```yaml
---
name: frontend-developer
description: Build modern, responsive frontends with React
model: sonnet
---

You are a frontend development specialist...

## Core Competencies
- Component-based architecture
- Modern CSS (Grid, Flexbox)
- State management
```

**Características:**
- Frontmatter: `name`, `description`, `model`
- Sin `context: fork` (mismo contexto)
- Instrucciones detalladas de competencias y estándares
- Claude los aplica automáticamente cuando son relevantes

**Cuándo usar:** Cuando necesitas un "experto" disponible pero no necesitas aislar el trabajo.

### 2. Subagents Aislados (contexto separado)

Agentes que corren en su **propia ventana de contexto** con herramientas restringidas.

```yaml
---
name: code-reviewer
description: Expert code review
tools: Read, Grep, Glob, Bash
context: fork
---

You are a senior code reviewer...
```

**Características:**
- Herramientas explícitamente restringidas
- Contexto aislado (no contamina conversación principal)
- Resultados se resumen al volver

**Cuándo usar:** Tareas con output verboso, operaciones que no deben afectar el contexto principal.

---

## Templates por Caso de Uso

### Desarrollo

| Template | Descripción | Herramientas sugeridas |
|----------|-------------|------------------------|
| `frontend-developer` | UI, componentes, CSS, React/Vue | Read, Edit, Bash |
| `backend-developer` | APIs, DBs, servers | Read, Edit, Bash, Grep |
| `api-developer` | REST, GraphQL, OpenAPI | Read, Edit, Bash |
| `mobile-developer` | React Native, Flutter, iOS/Android | Read, Edit, Bash |

### Lenguajes específicos

| Template | Descripción | Foco |
|----------|-------------|------|
| `python-developer` | PEP, Django/FastAPI, async | Typing, tests, poetry |
| `javascript-developer` | ES2024+, Node, async | Performance, modules |
| `typescript-developer` | Tipos avanzados, generics | Type safety, strict mode |
| `php-developer` | PHP 8.3+, Laravel/Symfony | OOP, security |

### Calidad

| Template | Descripción | Herramientas sugeridas |
|----------|-------------|------------------------|
| `code-reviewer` | PRs, auditoría, feedback | Read, Grep, Glob (solo lectura) |
| `code-debugger` | Root cause, troubleshooting | Read, Edit, Bash |
| `code-documenter` | Docs, comments, README | Read, Edit |
| `code-refactor` | Modernización, cleanup | Read, Edit, Bash |
| `code-security-auditor` | OWASP, vulnerabilidades | Read, Grep, Glob |
| `code-standards-enforcer` | Linting, estilo, convenciones | Read, Bash |

---

## Anatomía de un Skill Template

Estructura recomendada para skills de rol:

```yaml
---
name: role-name
description: Breve descripción de cuándo usar (Claude usa esto para decidir)
model: sonnet  # o haiku para tareas simples, opus para complejas
---

[Declaración de rol - 1 línea]

## Core Competencies
[Lista de áreas de expertise - 5-10 items]

## Development Philosophy / Principles
[Principios guía - 5-8 items numerados]

## Deliverables / Output Standards
[Qué debe entregar - 5-10 items]

[Instrucción final de enfoque]
```

### Ejemplo: Code Reviewer

```yaml
---
name: code-reviewer
description: Perform thorough code reviews focusing on security, performance, and maintainability
model: sonnet
---

You are a senior code review specialist.

## Review Focus Areas
- Code security vulnerabilities
- Performance bottlenecks
- Architectural patterns
- Test coverage
- Error handling

## Analysis Framework
1. Security-first mindset
2. Performance impact assessment
3. Maintainability evaluation
4. Code readability
5. Test coverage verification

## Review Categories
- **Critical**: Security vulnerabilities, data corruption
- **Major**: Performance problems, architectural violations
- **Minor**: Style, naming, documentation
- **Praise**: Well-implemented patterns

Provide thorough, actionable feedback that improves code quality.
```

---

## Patrones de Composición

### 1. Chain (secuencial)

Un skill/subagent alimenta al siguiente.

```
code-reviewer → code-refactor → code-documenter
```

**Uso:**
```
"Primero usa code-reviewer para encontrar issues,
luego code-refactor para arreglarlos,
finalmente code-documenter para actualizar docs"
```

### 2. Fork-Join (paralelo)

Múltiples subagents trabajan en paralelo, resultados se combinan.

```
        ┌─→ security-auditor ─┐
task ───┼─→ code-reviewer ────┼─→ merge results
        └─→ performance-check─┘
```

**Uso:**
```
"Ejecuta en paralelo: security-auditor, code-reviewer
y performance-check sobre estos cambios"
```

### 3. Wrapper (skill invoca subagent)

Un skill que internamente delega a un subagent aislado.

```yaml
---
name: safe-review
description: Review with isolated context
context: fork
agent: code-reviewer
---

Execute code-reviewer in isolated context.
Return only critical and major issues.
```

---

## Mejores Prácticas

### Naming conventions

| Patrón | Ejemplo | Uso |
|--------|---------|-----|
| `role-action` | `code-reviewer` | Agente con rol específico |
| `domain-task` | `db-reader` | Tarea en dominio específico |
| `action-target` | `fix-issue` | Acción sobre objetivo |

### Selección de modelo

| Modelo | Cuándo usar |
|--------|-------------|
| `haiku` | Búsquedas, lectura, tareas simples, bajo costo |
| `sonnet` | Balance capacidad/velocidad, la mayoría de tareas |
| `opus` | Razonamiento complejo, arquitectura, debugging difícil |
| `inherit` | Cuando debe usar el mismo modelo que la conversación |

### Selección de herramientas

| Principio | Aplicación |
|-----------|------------|
| **Mínimo necesario** | Solo herramientas que realmente necesita |
| **Solo lectura por defecto** | `Read, Grep, Glob` para reviewers |
| **Bash con cuidado** | Puede ejecutar cualquier comando |
| **Sin Write/Edit** | Para subagents que solo deben observar |

### Cuándo usar skill vs subagent

| Situación | Usar |
|-----------|------|
| Necesito un "experto" disponible | Skill (mismo contexto) |
| Output será muy verboso | Subagent (contexto aislado) |
| Quiero restringir herramientas estrictamente | Subagent con `tools:` |
| Múltiples tareas en paralelo | Subagents en background |
| Prompts reutilizables simples | Skill |
| Validación con hooks específicos | Subagent con `hooks:` |

---

## Ejemplo Completo: Development Workflow

Combinando múltiples patterns:

```yaml
# ~/.claude/skills/dev-workflow/SKILL.md
---
name: dev-workflow
description: Complete development workflow with review and docs
disable-model-invocation: true
---

Execute development workflow:

1. **Implement** - Write the code for $ARGUMENTS
2. **Review** - Use code-reviewer subagent to check quality
3. **Fix** - Address any critical/major issues found
4. **Document** - Update relevant documentation
5. **Verify** - Run tests to confirm changes work

Report summary of each phase.
```

Uso:
```
/dev-workflow add user authentication
```
