# Claude Code - Aprendizaje Completo

Documento consolidado con todo lo aprendido sobre Claude Code.

---

# 1. GESTIÓN DE SESIONES

## Comandos principales

| Comando | Acción | Recuperable |
|---------|--------|-------------|
| `/clear` | Borra TODO el historial | No |
| `/compact` | Comprime conversación | Parcial (resumen) |
| `Esc+Esc` o `/rewind` | Retrocede a checkpoint | Sí (selectivo) |
| `/resume` | Picker de sesiones anteriores | - |
| `claude --continue` | Retoma última sesión | - |
| `claude --resume` | Elige sesión al iniciar | - |

## /clear - Borrado total

**Qué se pierde:**
- Toda la conversación (prompts y respuestas)
- Contexto de archivos leídos
- Decisiones y planes discutidos

**Qué se mantiene:**
- Cambios en archivos (código ya escrito permanece)
- CLAUDE.md (se recarga)
- Configuración y permisos

**Cuándo usarlo:**
- Cambias de tarea no relacionada
- Corregiste a Claude 2+ veces sin éxito
- Contexto lleno de exploraciones fallidas

## Esc+Esc / /rewind - Retroceso quirúrgico

Muestra checkpoints de la conversación. Opciones al restaurar:
1. **Solo conversación** - Borra mensajes pero mantiene cambios en archivos
2. **Solo código** - Revierte archivos pero mantiene conversación
3. **Ambos** - Restaura todo al estado del checkpoint

## /compact - Compresión inteligente

```
/compact                          # Compresión automática
/compact "enfócate en los hooks"  # Con instrucciones específicas
```

## Patrón: Experimentación Segura

```
1. Exploras, preguntas, pruebas código
2. Aprendes qué funciona y qué no
3. Esc+Esc → vuelves al inicio
4. Das instrucciones precisas con tu conocimiento nuevo
```

**Triple beneficio:**
- Código limpio (reviertes cambios fallidos)
- Contexto limpio (liberas tokens de la exploración)
- Tu conocimiento (aprendiste, aunque Claude "olvide")

**Resumen:** Tú haces el trabajo cognitivo explorando, luego le das a Claude instrucciones directas como si ya supieras todo desde el principio.

---

# 2. CLI TOOLS VS PLUGINS

Preferir herramientas CLI instaladas sobre plugins. Son más eficientes en tokens.

## Tabla de equivalencias

| Funcionalidad | Plugin/MCP | CLI Equivalente | Instalación |
|---------------|------------|-----------------|-------------|
| GitHub | mcp-github | `gh` | `brew install gh` |
| Búsqueda código | - | `rg` (ripgrep) | `brew install ripgrep` |
| Búsqueda archivos | - | `fd` | `brew install fd` |
| JSON | - | `jq` | `brew install jq` |
| HTTP/APIs | mcp-fetch | `httpie` | `brew install httpie` |
| AWS | mcp-aws | `aws` | `brew install awscli` |
| Google Cloud | mcp-gcp | `gcloud` | `brew install google-cloud-sdk` |
| PostgreSQL | mcp-postgres | `psql` | `brew install postgresql` |
| Docker | mcp-docker | `docker` | Docker Desktop |

## Por qué preferir CLI

| Aspecto | CLI | Plugin/MCP |
|---------|-----|------------|
| Tokens | Mínimos | Más overhead |
| Velocidad | Directa | Capa adicional |
| Autenticación | Ya configurada | Requiere setup |
| Debugging | Puedes probar tú mismo | Más opaco |

## Cuándo SÍ usar plugins/MCP

- No existe CLI equivalente (Notion, Figma)
- El plugin ofrece funcionalidad específica no disponible en CLI
- Integración más profunda que el CLI no soporta

---

# 3. HOOKS

Comandos shell que se ejecutan automáticamente en puntos del ciclo de Claude Code. A diferencia de CLAUDE.md (advisory), los hooks son **determinísticos**.

## Eventos disponibles

| Evento | Cuándo se dispara | Uso típico |
|--------|-------------------|------------|
| `PreToolUse` | Antes de ejecutar herramienta | Validar/bloquear comandos |
| `PostToolUse` | Después de herramienta exitosa | Auto-formatear archivos |
| `PermissionRequest` | Al mostrar diálogo de permiso | Auto-aprobar/denegar |
| `UserPromptSubmit` | Usuario envía prompt | Validar/agregar contexto |
| `Stop` | Claude termina de responder | Verificar completitud |
| `SessionStart` | Inicio/resume de sesión | Cargar contexto, env vars |
| `SessionEnd` | Fin de sesión | Cleanup, logging |
| `Notification` | Claude envía notificación | Alertas personalizadas |

## Configuración

Archivos de settings:
1. `~/.claude/settings.json` - Usuario (global)
2. `.claude/settings.json` - Proyecto (commit a git)
3. `.claude/settings.local.json` - Local (no commit)

### Estructura básica

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolPattern",
        "hooks": [
          {
            "type": "command",
            "command": "tu-comando-aqui"
          }
        ]
      }
    ]
  }
}
```

## Códigos de salida

| Exit code | Comportamiento |
|-----------|----------------|
| `0` | Éxito |
| `2` | Error bloqueante, stderr se muestra a Claude |
| Otro | Error no bloqueante |

## Ejemplos prácticos

### Auto-formatear con Prettier
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read f; [[ $f == *.ts ]] && npx prettier --write \"$f\"; exit 0; }"
          }
        ]
      }
    ]
  }
}
```

### Notificación macOS
```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Esperando input\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

### Proteger archivos sensibles
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import json,sys; d=json.load(sys.stdin); p=d.get('tool_input',{}).get('file_path',''); sys.exit(2 if any(x in p for x in ['.env','.git/','secrets']) else 0)\""
          }
        ]
      }
    ]
  }
}
```

## CLAUDE.md vs Hooks

| Aspecto | CLAUDE.md | Hooks |
|---------|-----------|-------|
| Naturaleza | Advisory (sugerencia) | Determinístico |
| Cumplimiento | Claude puede ignorar | Garantizado |
| Uso | Preferencias, estilo | Reglas estrictas |

## Tipos de hooks

| Tipo | Qué hace |
|------|----------|
| `type: "command"` | Ejecuta comando bash |
| `type: "prompt"` | Usa LLM (Haiku) para evaluar |

## Evento PreCompact

Se dispara antes de compact (manual o auto).

**Matchers:**
- `manual` - desde /compact
- `auto` - autocompact automático

**Ejemplo: Bloquear autocompact para compact inteligente**
```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "auto",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Genera prompt de preservación y ejecuta /compact' >&2; exit 2"
          }
        ]
      }
    ]
  }
}
```

## Evento PostToolUse para detectar directorios

**Ejemplo: Avisar cuando se crea directorio sin rule**

Hook que detecta creación de directorios (nivel 1-2) y sugiere crear una rule en `.claude/rules/`.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/check-new-dir.sh"
          }
        ]
      }
    ]
  }
}
```

**Comportamiento:**
- Si no existe `.claude/rules/` → sugiere crear el sistema con link a docs
- Si existe pero no hay rule para el path → sugiere crear rule con frontmatter `paths:`
- Ignora: `node_modules/`, `.git/`, `dist/`, `.claude/`, etc.

---

# 4. MCP (Model Context Protocol)

Protocolo para conectar Claude Code con servicios externos cuando no hay CLI disponible.

## Comandos principales

```bash
claude mcp add <nombre> --transport <tipo> <url>
claude mcp list
claude mcp get <nombre>
claude mcp remove <nombre>
/mcp  # dentro de Claude Code
```

## Tipos de transporte

| Tipo | Uso | Ejemplo |
|------|-----|---------|
| HTTP | Servicios cloud (recomendado) | `--transport http https://mcp.notion.com/mcp` |
| SSE | Legacy (deprecated) | `--transport sse https://mcp.asana.com/sse` |
| stdio | Servidores locales | `--transport stdio -- npx -y @some/server` |

## Scopes

| Scope | Guardado en | Uso |
|-------|-------------|-----|
| `local` | `~/.claude.json` | Solo tú, solo este proyecto |
| `project` | `.mcp.json` | Compartido con equipo |
| `user` | `~/.claude.json` | Solo tú, todos proyectos |

## Servidores MCP populares

| Servidor | Comando |
|----------|---------|
| Notion | `claude mcp add notion --transport http https://mcp.notion.com/mcp` |
| Sentry | `claude mcp add sentry --transport http https://mcp.sentry.dev/mcp` |
| Figma | `claude mcp add figma --transport http https://mcp.figma.com/mcp` |
| Slack | `claude mcp add slack --transport http https://mcp.slack.com/mcp` |

## Cuándo NO necesitas MCP

Si ya tienes CLI autenticado, úsalo:
- GitHub → `gh` (ya autenticado)
- AWS → `aws`
- PostgreSQL → `psql`

MCP solo para servicios SIN CLI: Notion, Figma, Linear, etc.

---

# 5. BEST PRACTICES

## Principio fundamental

> La ventana de contexto se llena rápido y el rendimiento degrada cuando se llena.

## 1. Dale a Claude forma de verificar su trabajo

El consejo más importante. Tests, screenshots, comandos que confirmen éxito.

## 2. Explora → Planifica → Codifica

```
Plan Mode: Explorar → Planificar
Normal Mode: Implementar → Commit
```

## 3. /clear frecuentemente

- Entre tareas no relacionadas
- Después de 2+ correcciones fallidas

## 4. Usa subagents para investigar

Mantienen tu contexto limpio:
```
"Usa subagents para investigar cómo funciona el sistema de auth"
```

## 5. Contexto específico en prompts

| Mal | Bien |
|-----|------|
| "agrega tests" | "test para foo.py cubriendo logout. sin mocks" |
| "arregla el bug" | "login falla después de timeout. revisa src/auth/" |

## Anti-patrones

| Patrón | Solución |
|--------|----------|
| Mezclar tareas no relacionadas | `/clear` entre tareas |
| Corregir 3+ veces | `/clear` y mejor prompt |
| CLAUDE.md muy largo | Podar sin piedad |
| Exploración sin límites | Usar subagents |

---

# 6. ESTRUCTURA DE CLAUDE.md

## Jerarquía

```
~/.claude/CLAUDE.md          ← Global (siempre cargado)
proyecto/CLAUDE.md           ← Proyecto (siempre cargado)
proyecto/src/CLAUDE.md       ← Solo si trabajas en src/
proyecto/src/api/CLAUDE.md   ← Solo si trabajas en src/api/
```

## Qué incluir

- Comandos que Claude no puede adivinar
- Reglas de estilo diferentes a defaults
- Instrucciones de testing
- Decisiones arquitectónicas específicas
- CLIs disponibles para usar

## Qué NO incluir

- Lo que Claude puede inferir del código
- Convenciones estándar del lenguaje
- Documentación detallada (mejor linkear)
- Descripciones archivo por archivo

## Cómo hacer instrucciones obligatorias

CLAUDE.md es "advisory" - Claude puede ignorar instrucciones vagas. Para que se sigan:

| Técnica | Ejemplo |
|---------|---------|
| Usar **OBLIGATORIO** | `**OBLIGATORIO** - usar sistema de rules` |
| Decir qué NO hacer | `NO usar CLAUDE.md en subdirectorios` |
| Dar ejemplos concretos | Incluir snippet de código/formato |
| Link a docs | Referencia oficial para validar |

**Ejemplo efectivo:**
```markdown
## Al inicializar (/init)
**OBLIGATORIO - NO usar CLAUDE.md en subdirectorios. Usar rules:**
1. CLAUDE.md principal conciso
2. `.claude/rules/` con frontmatter `paths:`
```

---

# 6.1 SISTEMA DE RULES (.claude/rules/)

Sistema modular para instrucciones específicas por path. Alternativa moderna a CLAUDE.md en subdirectorios.

## Estructura

```
proyecto/.claude/rules/
├── api.md        → rules para src/api/**
├── tests.md      → rules para tests/**
└── frontend.md   → rules para src/components/**
```

## Formato de rule

```yaml
---
paths:
  - "src/api/**"
  - "src/services/**"
---
# Rules para API

- Usar async/await
- Validar inputs con zod
- Retornar errores con códigos HTTP apropiados
```

## Ventajas vs CLAUDE.md en subdirectorios

| Aspecto | CLAUDE.md subdirs | .claude/rules/ |
|---------|-------------------|----------------|
| Ubicación | Dispersos en proyecto | Centralizados |
| Activación | Por directorio de trabajo | Por globs en `paths:` |
| Flexibilidad | Un archivo por directorio | Un archivo puede cubrir múltiples paths |
| Mantenimiento | Difícil de rastrear | Todo en un lugar |

## Cuándo usar cada uno

- **CLAUDE.md raíz**: Instrucciones generales del proyecto (siempre cargado)
- **.claude/rules/**: Instrucciones específicas por área/feature
- **CLAUDE.md subdirs**: Legacy, preferir rules

Docs: https://code.claude.com/docs/en/memory#modular-rules-with-clauderules

---

# 7. SUBAGENTS

Asistentes AI especializados que corren en su propio contexto.

## Subagents Built-in

| Agent | Modelo | Uso |
|-------|--------|-----|
| **Explore** | Haiku | Búsqueda en codebase (solo lectura) |
| **Plan** | Hereda | Investigación para planificar |
| **general-purpose** | Hereda | Tareas complejas multi-paso |

## Crear subagents personalizados

### Via /agents (recomendado)
```
/agents → Create new agent → User-level
```

### Via archivo Markdown

Ubicación: `~/.claude/agents/` (usuario) o `.claude/agents/` (proyecto)

```markdown
---
name: code-reviewer
description: Reviews code for quality
tools: Read, Grep, Glob
model: sonnet
---

You are a code reviewer. Analyze code and provide
actionable feedback on quality and security.
```

## Campos de configuración

| Campo | Descripción |
|-------|-------------|
| `name` | Identificador único |
| `description` | Cuándo Claude debe usar este agent |
| `tools` | Herramientas permitidas |
| `model` | haiku, sonnet, opus, inherit |
| `hooks` | Hooks del ciclo de vida |

## Modelos

| Modelo | Uso |
|--------|-----|
| `haiku` | Rápido, bajo costo |
| `sonnet` | Balance capacidad/velocidad |
| `opus` | Razonamiento profundo |
| `inherit` | Mismo que conversación principal |

## Patrones de uso

### Aislar operaciones verbosas
```
"Usa un subagent para correr tests y reportar solo fallos"
```

### Research en paralelo
```
"Investiga auth, database y API en paralelo con subagents"
```

### Encadenar
```
"Usa reviewer para encontrar issues, luego optimizer para arreglarlos"
```

## Foreground vs Background

| Modo | Comportamiento |
|------|----------------|
| Foreground | Bloquea, permisos interactivos |
| Background | Concurrente, permisos pre-aprobados |

`Ctrl+B` para enviar a background.

## Cuándo usar cada cosa

- **Conversación principal**: Back-and-forth, fases que comparten contexto
- **Subagent**: Output verboso, restricciones, trabajo autocontenido
- **Skill**: Prompts reutilizables en contexto principal

**Nota**: Subagents NO pueden crear otros subagents.

---

# 7. SKILLS

Archivos SKILL.md que extienden lo que Claude puede hacer.

## Ubicaciones

| Ubicación | Path |
|-----------|------|
| Personal | `~/.claude/skills/<nombre>/SKILL.md` |
| Proyecto | `.claude/skills/<nombre>/SKILL.md` |

## Formato SKILL.md

```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
allowed-tools: Bash, Read, Edit
---

Fix GitHub issue $ARGUMENTS:
1. Read issue with gh issue view
2. Implement fix
3. Write tests
4. Commit
```

## Campos importantes

| Campo | Descripción |
|-------|-------------|
| `name` | Nombre para /nombre |
| `description` | Cuándo usarlo |
| `disable-model-invocation` | `true` = solo tú invocas |
| `allowed-tools` | Herramientas sin pedir permiso |
| `context` | `fork` para correr en subagent |

## Variables

- `$ARGUMENTS` - todo lo que pases después del nombre
- `$0`, `$1`, etc. - argumentos por posición
- `!`comando`` - ejecuta antes de enviar a Claude

## Tipos de skills

| Tipo | Uso | Config |
|------|-----|--------|
| Referencia | Conocimiento que Claude aplica | default |
| Tarea | Acciones que tú controlas | `disable-model-invocation: true` |

---

# 8. PLUGINS

Paquetes que agrupan skills, agents, hooks y MCP servers.

## Estructura

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # Manifest
├── skills/              # Skills
├── agents/              # Subagents
├── hooks/hooks.json     # Hooks
└── .mcp.json            # MCP servers
```

## Manifest

```json
{
  "name": "my-plugin",
  "description": "What it does",
  "version": "1.0.0"
}
```

## Probar plugin

```bash
claude --plugin-dir ./my-plugin
```

## Skills vs Plugins

| Aspecto | Skills | Plugins |
|---------|--------|---------|
| Nombre | `/hello` | `/plugin:hello` |
| Uso | Personal, proyecto | Compartir, distribuir |

---

# 9. STATUSLINE PERSONALIZADA

## Configuración

En `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

## Datos disponibles (JSON por stdin)

| Campo | Descripción |
|-------|-------------|
| `model.display_name` | Nombre del modelo (Opus 4.5, Sonnet, etc.) |
| `context_window.used_percentage` | % de contexto usado |
| `context_window.context_window_size` | Tamaño total del contexto |
| `workspace.current_dir` | Directorio actual |
| `session_id` | ID de sesión |
| `cost.total_cost_usd` | Costo acumulado |

## Ejemplo: Doble porcentaje (real + relativo a autocompact)

```
[Opus 4.5] 🟢 39% →42% (78K/200K) | proyecto | 📁 main
```

- `39%` = % real del contexto
- `→42%` = % relativo al autocompact (100% = inminente)
- Círculo: 🟢 <80% | 🟡 80-99% | 🔴 100%

## Fórmula del % relativo

```bash
# Umbral = 100% - autocompact_buffer (16.5%) ≈ 84%
AUTOCOMPACT_THRESHOLD=84
RELATIVE_PCT=$(echo "scale=0; $USED_PCT * 100 / $AUTOCOMPACT_THRESHOLD" | bc)
```

## Cómo calcular el umbral

Ejecuta `/context` y mira:
```
⛝ Autocompact buffer: 33.0k tokens (16.5%)
```

Umbral = 100% - 16.5% = **83.5%** ≈ 84%

---

# RESUMEN: CUÁNDO USAR QUÉ

| Necesidad | Solución |
|-----------|----------|
| Workflow personal | Skill en `~/.claude/skills/` |
| Proyecto específico | Skill en `.claude/skills/` |
| Compartir con equipo | Plugin |
| Automatización garantizada | Hook |
| Contexto aislado | Subagent |
| Servicios externos sin CLI | MCP server |
| Servicios externos con CLI | Usar el CLI directamente |

---

# RECURSOS

## Documentación oficial
- https://code.claude.com/docs/en/

## Comunidad
- https://github.com/hesreallyhim/awesome-claude-code
- https://github.com/zebbern/claude-code-guide

## Mis CLIs instalados
- `gh` (GitHub) - autenticado
- `rg` (ripgrep) - búsqueda en código
- `fd` - búsqueda de archivos
- `jq` - manipulación JSON
- `httpie` - APIs REST
