# Chris Dunlop Workflow - Build Loop de 35 minutos

Workflow opinado para obtener código útil rápido sin crear deuda técnica. Enfocado en agentes especializados, feedback loops cortos y diffs limpios.

**Fuente:** [The Claude Code Workflow You Can Copy](https://medium.com/@chrisdunlop_/the-claude-code-workflow-you-can-copy-6e8b9f9b9b9b) (Aug 2025)

## Filosofía Core

1. **Patch diffs, no prose** - Cambios quirúrgicos, máx 3 archivos
2. **Contexto comprimido** - CONTEXT.md pequeño (≤200 líneas)
3. **Agentes especializados** - 5 roles, reutilizables
4. **Loops cortos** - 35 minutos por ciclo (evita scope creep)
5. **Docs vivos** - Decisiones, tareas y playbook actualizados

## Setup Inicial (One-time)

```
/docs/01-scope.md         # Single source of truth (goals & constraints)
/docs/02-decisions.md     # Architecture Decision Records (ADR-style, <10 bullets)
/docs/03-tasks.md         # Running task list con checkboxes
/PLAYBOOK.md              # "How this project works" para future-you
/CONTEXT.md               # Resumen comprimido que Claude lee primero (≤200 líneas)
/src/                     # Código
/tests/                   # Tests
/scripts/                 # Utilidades one-off
```

**CONTEXT.md:** Describir módulos, data shapes, APIs, non-negotiables. Actualizar después de cada milestone.

## Los 5 Agentes Especializados

Crear una vez en `claude update → /agents`, reutilizar siempre:

### 1. mvp-planner
**Role:** Convertir goal vago en MVP con scope claro.

**Always output:**
- Lista "We will NOT build"
- Riesgos con mitigaciones
- JSON backlog `[{id, title, acceptance}]`

### 2. ui-stylist
**Role:** Restyling de componentes según design tokens (typography, spacing, color).

**Constraints:**
- No cambiar librerías sin aprobación
- Return patch diff only

### 3. bug-fixer
**Role:** Reproduce → test que falla → fix → patch mínimo.

**Always include:** Root cause en 1-2 oraciones.

### 4. modular-architect
**Role:** Proponer estructura de directorios, boundaries, interfaces.

**Output:**
- ASCII module map
- Razones para cada boundary

### 5. reviewer-readonly
**Role:** Code review SIN edits.

**Return:**
- Inline comments
- Risk ranking (High/Med/Low)
- Decisión "merge/no-merge"

**Nota:** Claude auto-rutea según el prompt. Si no lo hace, llamar al agente explícitamente.

## Loop de 35 Minutos (Build Loop)

Ejecutar hasta shipear. El constraint mantiene calidad alta.

### Minuto 0-5: Frame
- Editar `/docs/01-scope.md` (qué hacer next, acceptance)
- Actualizar `/CONTEXT.md` si estructura cambió

### Minuto 5-20: Build
- Prompt con **una tarea atómica** (ver templates)
- Pedir **patch diff, no prose**
- Si hay ruido: "same patch but smaller (touch max 3 files)"

### Minuto 20-30: Test
- Request failing test primero, luego fix
- Run localmente, keep logs
- Trim scope si es necesario

### Minuto 30-35: Commit & Compress
- Commit: `feat: add invoice export (csv)`
- Append una línea a `/docs/02-decisions.md` si hubo decisión
- Rewrite `/CONTEXT.md` deltas (mantener <200 líneas)

**Repeat.**

## Prompt Templates

### A. New Feature (atomic)

```
Goal: [one sentence]
Constraints: [stack, libraries, patterns que deben permanecer]
Touch budget: max 3 files
Return: unified PATCH DIFF only + brief rationale (≤3 bullets)
Use CONTEXT.md to preserve architecture.
```

### B. Styling Pass (no logic changes)

```
Apply design tokens (font scale, spacing, radius).
No JS behaviour edits.
Return patch diff for *.tsx/*.css only.
If tokens missing, create tokens.ts and refactor to use it.
```

### C. Bug Fix with Safety Rails

```
Reproduce bug: [steps]
Write failing test first in /tests/[name].spec.ts.
Then propose smallest fix.
Return: test diff + code diff.
Explain root cause in 2 sentences.
```

### D. "Too Big" Response Recovery

```
Your patch is too large. Split into sequential patches of ≤50 lines each.
Return only PATCH 1 now. I will apply and ask for PATCH 2.
```

## Stuck Ladder (en orden)

Cuando te atascas, escala en este orden:

1. **Narrow the ask** - Un archivo, una función
2. **Add concrete example** - Input/output JSON
3. **Duplicate page & reframe** - Fresh context a menudo rutea el agente correcto
4. **Switch persona** - Llamar `modular-architect` para reshape antes de codear
5. **Cut surface area** - Feature flag, shipear slice más pequeño

**Si sigues stuck después de 20 min:** Estás resolviendo el problema equivocado. Vuelve a `/docs/01-scope.md`.

## Scaling a Large Codebases

**Compress first:**
```
Summarise repo by modules, public interfaces, data contracts. ≤180 lines.
Highlight coupling hotspots. Output to CONTEXT.md (overwrite).
```

**Estrategias:**
- **Work in slices:** "Only touch /src/billing/*" - Claude respeta fences cuando las declaras
- **Batch refactors:** Lock logic, correr ui-stylist o linting como patches separados (evita noisy diffs)
- **Index hotspots:** Lista corta en top de CONTEXT.md: "Here be dragons" con file paths

## Ship Ritual (Checklist)

Antes de mergear:

- [ ] `reviewer-readonly` agent dice "merge" (no edits)
- [ ] Tests run localmente (even if minimal)
- [ ] Docs bumped (una línea en decisions + API shape changes)
- [ ] Release note (3 bullets: what changed, risk, rollback)

## Copy-Paste Starter Pack

### House Rules (top de cada sesión)

```
House Rules:
- Return patch diffs, not prose.
- Respect /CONTEXT.md constraints.
- If unsure, propose 2 options with trade-offs (≤80 words).
- Keep changes surgical: max 3 files unless I expand scope.
- If more than 3 files tell me why and what
```

### First Message (nuevo proyecto)

```
Read CONTEXT.md and 01-scope.md.
Propose a clear MVP plan with a JSON backlog.
List what we will NOT build.
Then wait.
```

## FAQ

**¿Por qué patch diffs?**
Anclan a Claude a cambiar menos → edits más seguros. Tools como v0 o ChatGPT regeneran el archivo entero (más lento).

**¿Por qué CONTEXT.md?**
Es el guardrail. Claude lo lee; tú lo mantienes.

**¿Por qué 35 minutos?**
Lo suficientemente largo para terminar un slice, lo suficientemente corto para evitar scope creep. Si no puedes shipear features a cadencia regular, tu scope es demasiado grande.

**¿Por qué 5 agentes?**
Más agentes ≠ más velocidad. Estos 5 cubren el 95% del trabajo. Demasiados agentes confunden el routing.

## Comparación con ClaudeLearn Setup

| Concepto | Chris Dunlop | ClaudeLearn Actual |
|----------|--------------|-------------------|
| **Context file** | `CONTEXT.md` (≤200 líneas) | `CLAUDE.md` + `.claude/rules/` (modular) |
| **Agentes** | 5 custom en `/agents` | Task tool con Explore/Plan |
| **Routing de modelos** | Por prompt match a agentes | Auto-Router Proxy (haiku/sonnet/opus) |
| **Decisions log** | `02-decisions.md` ADRs | ❌ No implementado |
| **Task tracking** | `03-tasks.md` checkboxes | TaskCreate/TaskUpdate tools |
| **Patch diffs** | Enfoque principal | No forzado explícitamente |
| **Loop timing** | 35 min estrictos | Sin límite de tiempo |
| **Stuck protocol** | Stuck Ladder (5 pasos) | ❌ No documentado |

## Ideas Adoptables

### ✅ Ya tienes equivalentes
- **CONTEXT.md** → Tu sistema de `.claude/rules/` es más modular
- **Agentes** → Usas Explore/Plan subagents
- **Task tracking** → TaskCreate/TaskUpdate

### 🟡 Podrías adoptar
1. **Decisions log** (`02-decisions.md`) - ADRs para trackear decisiones arquitectónicas
2. **"Patch diffs only"** - Agregar a CLAUDE.md: "Return patch diffs, max 3 files"
3. **Stuck Ladder** - Agregar a workflows como checklist mental
4. **35-min loop** - Límite de tiempo para evitar scope creep
5. **Ship ritual** - Checklist antes de commits importantes

### ❌ No aplica
- **Agentes custom en /agents** - Ya tienes Explore/Plan que cubren lo necesario
- **PLAYBOOK.md separado** - Tu CLAUDE.md + APRENDIZAJE-COMPLETO.md cumplen ese rol

## Ejemplo: Feature from Nothing

**Brief:** "Export invoices to CSV with filters."

1. **Scope:** Add "Export CSV" button, filter by date/status, job finishes
2. **modular-architect:** Adds `/src/export` module con interface
3. **Feature prompt (atomic):** Returns patch para service + controller + button stub
4. **bug-fixer:** Writes failing test para timezone edge case, luego patch
5. **Commit + decisions:** "CSV uses UTC; display converts to local."

## Recursos

- [Artículo original](https://medium.com/@chrisdunlop_) - Chris Dunlop, Aug 2025
- [Ejemplo de patch diff workflow](https://medium.com/@chrisdunlop_/patch-diff-example)
