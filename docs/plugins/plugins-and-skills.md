# Plugins y Skills - Claude Code

Sources:
- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/skills

---

## Skills vs Plugins

| Aspecto | Skills (standalone) | Plugins |
|---------|---------------------|---------|
| Nombre | `/hello` | `/plugin-name:hello` |
| Ubicación | `.claude/skills/` | directorio con `.claude-plugin/` |
| Uso ideal | Personal, proyecto específico | Compartir con equipo, distribuir |
| Versionado | No | Sí (semver) |

**Recomendación**: Empieza con skills standalone, convierte a plugin cuando necesites compartir.

---

## Commands vs Skills (fusión v2.1.3)

Desde la versión 2.1.3, commands y skills son funcionalmente equivalentes:

| Aspecto | Commands | Skills |
|---------|----------|--------|
| Ubicación | `.claude/commands/archivo.md` | `.claude/skills/nombre/SKILL.md` |
| Estructura | Archivo único | Directorio (con archivos de soporte) |
| Nombre del comando | Viene del filename | Viene del frontmatter `name:` |
| Auto-discovery | Sí | Sí |
| Frontmatter | Completo | Completo |

**Cuándo usar cada uno:**

| Caso de uso | Usar |
|-------------|------|
| Comando simple, sin archivos adicionales | `.claude/commands/` |
| Workflow con templates, scripts, o configs | `.claude/skills/` |
| Compartir/distribuir | Plugin |

Ambos soportan:
- Invocación con `/nombre`
- Auto-invocación por Claude basada en `description`
- Variables `$ARGUMENTS`, `$N`
- Todos los campos de frontmatter
- Hot reload

---

# SKILLS

## Qué son

Archivos SKILL.md que extienden lo que Claude puede hacer. Claude los usa automáticamente cuando son relevantes, o los invocas con `/skill-name`.

## Ubicaciones

| Ubicación | Path | Alcance |
|-----------|------|---------|
| Personal | `~/.claude/skills/<nombre>/SKILL.md` | Todos tus proyectos |
| Proyecto | `.claude/skills/<nombre>/SKILL.md` | Solo este proyecto |
| Plugin | `<plugin>/skills/<nombre>/SKILL.md` | Donde plugin está habilitado |

## Hot Reload (desde v2.1.0)

Los cambios en skills y commands se detectan automáticamente. No necesitas reiniciar la sesión de Claude Code para que los cambios tengan efecto.

## Estructura básica

```
my-skill/
├── SKILL.md           # Instrucciones principales (requerido)
├── template.md        # Template para Claude
├── examples/          # Ejemplos
└── scripts/           # Scripts que Claude puede ejecutar
```

## Formato SKILL.md

```yaml
---
name: fix-issue
description: Fix a GitHub issue by number
disable-model-invocation: true
allowed-tools: Bash, Read, Edit
---

Fix GitHub issue $ARGUMENTS:

1. Read the issue with gh issue view
2. Understand requirements
3. Implement fix
4. Write tests
5. Create commit
```

## Campos del frontmatter

| Campo | Descripción |
|-------|-------------|
| `name` | Nombre del skill (se usa para /nombre) |
| `description` | Cuándo usarlo (Claude usa esto para decidir) |
| `disable-model-invocation` | `true` = solo tú puedes invocarlo |
| `user-invocable` | `false` = solo Claude puede invocarlo |
| `allowed-tools` | Herramientas permitidas sin pedir permiso |
| `model` | Modelo a usar |
| `context` | `fork` para correr en subagent |
| `agent` | Tipo de subagent si context: fork |

## Variables de sustitución

| Variable | Descripción |
|----------|-------------|
| `$ARGUMENTS` | Todo lo que pases después del nombre |
| `$ARGUMENTS[N]` o `$N` | Argumento específico por índice |
| `${CLAUDE_SESSION_ID}` | ID de sesión actual |

## Tipos de skills

### 1. Referencia (conocimiento)
Claude lo aplica a tu trabajo actual.

```yaml
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming
- Return consistent error formats
- Include validation
```

### 2. Tarea (acción)
Instrucciones paso a paso. Usa `disable-model-invocation: true`.

```yaml
---
name: deploy
description: Deploy to production
disable-model-invocation: true
---

Deploy the application:
1. Run tests
2. Build
3. Push to production
```

## Quién puede invocar

| Configuración | Tú | Claude |
|---------------|----|----|
| (default) | Sí | Sí |
| `disable-model-invocation: true` | Sí | No |
| `user-invocable: false` | No | Sí |

## Contexto dinámico con !`comando`

Ejecuta comandos ANTES de enviar a Claude:

```yaml
---
name: pr-summary
description: Summarize PR changes
---

## PR Context
- Diff: !`gh pr diff`
- Comments: !`gh pr view --comments`

Summarize this PR...
```

## Skills en subagent

Usa `context: fork` para aislar:

```yaml
---
name: deep-research
description: Research thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS:
1. Find relevant files
2. Analyze code
3. Summarize findings
```

## Ejemplos prácticos

### Code reviewer
```yaml
---
name: review
description: Review code changes
allowed-tools: Read, Grep, Glob, Bash
---

Review the recent changes:
1. Run git diff
2. Check for issues
3. Provide feedback by priority
```

### Fix GitHub issue
```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---

Fix issue #$ARGUMENTS:
1. gh issue view $ARGUMENTS
2. Understand the problem
3. Implement fix
4. Write tests
5. Commit with message "fix: resolve #$ARGUMENTS"
```

### Commit con convención
```yaml
---
name: commit
description: Create conventional commit
disable-model-invocation: true
---

Create a commit:
1. Review staged changes with git diff --staged
2. Generate commit message: type(scope): description
3. Execute git commit
```

---

# PLUGINS

## Qué son

Paquetes que agrupan skills, agents, hooks, y MCP servers para distribuir.

## Estructura

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # Manifest (requerido)
├── skills/              # Skills
├── commands/            # Comandos simples (archivo único)
├── agents/              # Subagents
├── hooks/
│   └── hooks.json       # Hooks
├── .mcp.json            # MCP servers
└── .lsp.json            # LSP servers
```

**IMPORTANTE**: Solo `plugin.json` va dentro de `.claude-plugin/`. Todo lo demás en la raíz del plugin.

## Manifest (plugin.json)

```json
{
  "name": "my-plugin",
  "description": "What this plugin does",
  "version": "1.0.0",
  "author": {
    "name": "Your Name"
  }
}
```

## Crear plugin

### 1. Crear estructura
```bash
mkdir -p my-plugin/.claude-plugin
mkdir -p my-plugin/skills/hello
```

### 2. Crear manifest
```json
// my-plugin/.claude-plugin/plugin.json
{
  "name": "my-plugin",
  "description": "My first plugin",
  "version": "1.0.0"
}
```

### 3. Agregar skill
```yaml
# my-plugin/skills/hello/SKILL.md
---
name: hello
description: Greet the user
---

Greet the user warmly.
```

### 4. Probar localmente
```bash
claude --plugin-dir ./my-plugin
```

### 5. Usar
```
/my-plugin:hello
```

## Instalar plugins

```
/plugin install <url-or-path>
```

## Convertir standalone a plugin

1. Crear estructura de plugin
2. Copiar archivos:
   - `.claude/skills/` → `plugin/skills/`
   - `.claude/agents/` → `plugin/agents/`
3. Crear hooks.json con hooks de settings.json
4. Probar con `--plugin-dir`

---

## Resumen: Cuándo usar qué

| Necesidad | Solución |
|-----------|----------|
| Workflow personal | Skill en `~/.claude/skills/` |
| Proyecto específico | Skill en `.claude/skills/` |
| Compartir con equipo | Plugin con skills |
| Automatización garantizada | Hook |
| Contexto aislado | Subagent o skill con `context: fork` |
| Servicios externos | MCP server (o CLI si disponible) |
