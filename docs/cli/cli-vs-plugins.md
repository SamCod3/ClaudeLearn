# CLI Tools vs Plugins

Preferir herramientas CLI instaladas sobre plugins cuando estén disponibles. Son más eficientes en tokens y Claude ya sabe usarlas.

## Tabla de equivalencias

| Funcionalidad | Plugin/MCP | CLI Equivalente | Instalación |
|---------------|------------|-----------------|-------------|
| **GitHub** | mcp-github | `gh` | `brew install gh` |
| **Git** | - | `git` | Ya instalado |
| **GitLab** | mcp-gitlab | `glab` | `brew install glab` |
| **Búsqueda código** | - | `rg` (ripgrep) | `brew install ripgrep` |
| **Búsqueda archivos** | - | `fd` | `brew install fd` |
| **JSON** | - | `jq` | `brew install jq` |
| **HTTP/APIs** | mcp-fetch | `curl` / `httpie` | `brew install httpie` |
| **AWS** | mcp-aws | `aws` | `brew install awscli` |
| **Google Cloud** | mcp-gcp | `gcloud` | `brew install google-cloud-sdk` |
| **Azure** | mcp-azure | `az` | `brew install azure-cli` |
| **Docker** | mcp-docker | `docker` | Docker Desktop |
| **Kubernetes** | mcp-kubernetes | `kubectl` | `brew install kubectl` |
| **PostgreSQL** | mcp-postgres | `psql` | `brew install postgresql` |
| **MySQL** | mcp-mysql | `mysql` | `brew install mysql-client` |
| **SQLite** | mcp-sqlite | `sqlite3` | Ya instalado (macOS) |
| **MongoDB** | mcp-mongodb | `mongosh` | `brew install mongosh` |
| **Redis** | mcp-redis | `redis-cli` | `brew install redis` |
| **Terraform** | - | `terraform` | `brew install terraform` |
| **npm/Node** | - | `npm` / `pnpm` | Ya con Node.js |
| **Python** | - | `pip` / `uv` | `brew install uv` |
| **Sentry** | mcp-sentry | `sentry-cli` | `brew install getsentry/tools/sentry-cli` |
| **Slack** | mcp-slack | `slack-cli` | npm install -g @slack/cli |
| **Notion** | mcp-notion | - | No hay CLI oficial |
| **Figma** | mcp-figma | - | No hay CLI oficial |
| **Linear** | mcp-linear | `linear` | npm install -g @linear/cli |

## Por qué preferir CLI

| Aspecto | CLI | Plugin/MCP |
|---------|-----|------------|
| **Tokens** | Mínimos (comandos cortos) | Más overhead |
| **Velocidad** | Ejecución directa | Capa adicional |
| **Autenticación** | Ya configurada en tu sistema | Requiere setup en Claude |
| **Conocimiento** | Claude conoce CLIs populares | Puede no conocer el plugin |
| **Debugging** | Puedes probar comandos tú mismo | Más opaco |
| **Offline** | Funciona sin internet (algunos) | Requiere conexión |

## Cuándo SÍ usar plugins/MCP

- No existe CLI equivalente (Notion, Figma)
- El plugin ofrece funcionalidad específica no disponible en CLI
- Integración más profunda que el CLI no soporta
- Preferencia personal / workflow específico

## Configuración recomendada

### 1. Instalar CLIs esenciales
```bash
# macOS con Homebrew
brew install gh ripgrep fd jq httpie

# Verificar instalación
gh --version
rg --version
```

### 2. Autenticar CLIs
```bash
gh auth login          # GitHub
aws configure          # AWS
gcloud auth login      # Google Cloud
az login               # Azure
```

### 3. Indicar a Claude que use CLIs
En tu CLAUDE.md:
```markdown
## CLI Tools (preferir sobre plugins)
- gh: GitHub (issues, PRs, API)
- rg: búsqueda en código
- jq: manipulación JSON
- aws/gcloud/az: cloud providers
```

## Ejemplos de uso

### GitHub: Plugin vs CLI

**Con plugin:**
```
[Claude usa mcp-github tool]
[overhead de protocolo MCP]
[respuesta]
```

**Con CLI:**
```bash
gh issue list --state open
gh pr create --title "feat: add auth" --body "..."
gh api repos/owner/repo/pulls/123
```

### Base de datos: Plugin vs CLI

**Con plugin:**
```
[mcp-postgres connection]
[query via MCP protocol]
```

**Con CLI:**
```bash
psql -d mydb -c "SELECT * FROM users LIMIT 10"
```

### Búsqueda: Herramientas internas vs CLI

Claude tiene Grep/Glob internos, pero `rg` y `fd` son más potentes:

```bash
# Buscar patrón en código
rg "TODO|FIXME" --type ts

# Buscar archivos por nombre
fd "\.test\.ts$"

# Combinar
fd -e ts | xargs rg "async function"
```

## Resumen

```
¿Existe CLI para esto?
        │
        ├─ SÍ → Usar CLI (más eficiente)
        │
        └─ NO → ¿Es crítico para el workflow?
                    │
                    ├─ SÍ → Instalar plugin/MCP
                    │
                    └─ NO → Probablemente no lo necesitas
```
