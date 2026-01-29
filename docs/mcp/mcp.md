# MCP - Model Context Protocol

Source: https://code.claude.com/docs/en/mcp

## Qué es MCP

Protocolo abierto para conectar Claude Code con herramientas externas: bases de datos, APIs, servicios cloud, etc. Los MCP servers dan acceso a datos y funcionalidades que Claude no tiene nativamente.

## Qué puedes hacer con MCP

- **Issue trackers**: "Implementa la feature descrita en JIRA ENG-4521"
- **Monitoreo**: "Revisa errores en Sentry de las últimas 24h"
- **Bases de datos**: "Busca usuarios que no han comprado en 90 días"
- **Diseño**: "Actualiza el componente según el diseño en Figma"
- **Workflows**: "Crea drafts en Gmail para invitar a estos usuarios"

---

## CLI vs MCP: Cuándo usar cada uno

| Si tienes... | Usar |
|--------------|------|
| CLI instalado y autenticado (gh, aws, gcloud) | CLI directamente |
| Servicio sin CLI (Notion, Figma, Sentry) | MCP server |
| Necesitas integración profunda | MCP server |

**Recuerda**: Ya tienes `gh` autenticado → no necesitas MCP de GitHub.

---

## Comandos principales

```bash
# Agregar servidor
claude mcp add <nombre> --transport <tipo> <url>

# Listar servidores
claude mcp list

# Ver detalles
claude mcp get <nombre>

# Eliminar
claude mcp remove <nombre>

# Dentro de Claude Code
/mcp
```

---

## Tipos de transporte

### HTTP (recomendado para servicios cloud)
```bash
claude mcp add notion --transport http https://mcp.notion.com/mcp
```

### SSE (Server-Sent Events) - deprecated
```bash
claude mcp add asana --transport sse https://mcp.asana.com/sse
```

### Stdio (servidores locales)
```bash
claude mcp add db --transport stdio -- npx -y @some/mcp-server
```

---

## Scopes (alcance de configuración)

| Scope | Guardado en | Uso |
|-------|-------------|-----|
| `local` | `~/.claude.json` | Solo tú, solo este proyecto (default) |
| `project` | `.mcp.json` | Compartido con equipo (commit a git) |
| `user` | `~/.claude.json` | Solo tú, todos tus proyectos |

```bash
# Agregar con scope específico
claude mcp add sentry --scope user --transport http https://mcp.sentry.dev/mcp
```

---

## Autenticación OAuth

Muchos MCP servers requieren autenticación:

```bash
# 1. Agregar el servidor
claude mcp add sentry --transport http https://mcp.sentry.dev/mcp

# 2. Dentro de Claude Code, autenticar
/mcp
# Seguir pasos en el navegador
```

---

## Ejemplos prácticos

### Sentry (monitoreo de errores)
```bash
claude mcp add sentry --transport http https://mcp.sentry.dev/mcp
```
```
> "¿Cuáles son los errores más comunes en las últimas 24h?"
> "Muéstrame el stack trace del error abc123"
```

### PostgreSQL (base de datos)
```bash
claude mcp add db --transport stdio -- npx -y @bytebase/dbhub \
  --dsn "postgresql://user:pass@host:5432/dbname"
```
```
> "¿Cuál es el revenue total de este mes?"
> "Muéstrame el schema de la tabla orders"
```

### Notion
```bash
claude mcp add notion --transport http https://mcp.notion.com/mcp
# Luego /mcp para autenticar
```

### Figma
```bash
claude mcp add figma --transport http https://mcp.figma.com/mcp
# Luego /mcp para autenticar
```

---

## Configuración en .mcp.json (para equipos)

Archivo en raíz del proyecto, se commitea a git:

```json
{
  "mcpServers": {
    "company-api": {
      "type": "http",
      "url": "${API_BASE_URL}/mcp",
      "headers": {
        "Authorization": "Bearer ${API_KEY}"
      }
    }
  }
}
```

Soporta variables de entorno con `${VAR}` y defaults `${VAR:-default}`.

---

## Usar recursos MCP con @

Los MCP servers pueden exponer recursos que referencias con @:

```
> Analiza @github:issue://123 y sugiere un fix
> Compara @postgres:schema://users con @docs:file://database/user-model
```

---

## MCP Prompts como comandos

Los MCP servers pueden exponer prompts como comandos /:

```
/mcp__github__list_prs
/mcp__github__pr_review 456
/mcp__jira__create_issue "Bug en login" high
```

---

## Variables de entorno útiles

| Variable | Descripción |
|----------|-------------|
| `MCP_TIMEOUT` | Timeout de startup (ms), default 30000 |
| `MAX_MCP_OUTPUT_TOKENS` | Límite de output, default 25000 |
| `ENABLE_TOOL_SEARCH` | auto/true/false para búsqueda dinámica |

```bash
MCP_TIMEOUT=10000 MAX_MCP_OUTPUT_TOKENS=50000 claude
```

---

## Claude Code como MCP server

Puedes usar Claude Code como servidor MCP para otras apps:

```bash
claude mcp serve
```

En Claude Desktop (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "claude-code": {
      "type": "stdio",
      "command": "claude",
      "args": ["mcp", "serve"]
    }
  }
}
```

---

## Servidores MCP populares

| Servidor | Para qué | Comando |
|----------|----------|---------|
| Notion | Docs y wikis | `claude mcp add notion --transport http https://mcp.notion.com/mcp` |
| Sentry | Monitoreo errores | `claude mcp add sentry --transport http https://mcp.sentry.dev/mcp` |
| Figma | Diseños | `claude mcp add figma --transport http https://mcp.figma.com/mcp` |
| Slack | Mensajería | `claude mcp add slack --transport http https://mcp.slack.com/mcp` |
| Linear | Issues | `claude mcp add linear --transport http https://mcp.linear.app/mcp` |
| Asana | Gestión proyectos | `claude mcp add asana --transport sse https://mcp.asana.com/sse` |

**Más servidores**: https://github.com/modelcontextprotocol/servers

---

## Importar desde Claude Desktop

Si ya tienes MCP servers en Claude Desktop:

```bash
claude mcp add-from-claude-desktop
# Selecciona cuáles importar
```

---

## Cuándo NO necesitas MCP

Si ya tienes CLI autenticado, úsalo directamente:

| Servicio | CLI | MCP necesario? |
|----------|-----|----------------|
| GitHub | `gh` ✅ | No |
| AWS | `aws` ✅ | No |
| GCloud | `gcloud` ✅ | No |
| PostgreSQL | `psql` ✅ | No |
| Notion | ❌ | Sí |
| Figma | ❌ | Sí |
| Sentry | `sentry-cli` (limitado) | Recomendado |
