# MCP Session Manager

MCP server personalizado para gestión de sesiones de Claude Code. Centraliza backup, indexado y búsqueda de sesiones.

## Ubicación

```
~/.claude/mcp-servers/session-manager/
├── src/
│   ├── index.ts              # Entry point + tool registry
│   └── tools/
│       ├── session-search.ts  # Búsqueda FTS5
│       ├── session-list.ts    # Listar sesiones
│       ├── session-context.ts # Cargar contexto
│       ├── session-save.ts    # Guardar sesión (hook)
│       ├── backup.ts          # Backups incrementales
│       └── code-analysis.ts   # Búsqueda AST
├── dist/                      # Compilado
├── package.json
└── tsconfig.json
```

## Funciones disponibles

| Función | Descripción | Uso |
|---------|-------------|-----|
| `session_search` | Búsqueda FTS5 en historial | Claude |
| `session_list` | Listar sesiones por proyecto | Claude |
| `session_get_context` | Cargar contexto de sesión | Claude |
| `session_save` | Guardar sesión + indexar | Hooks |
| `backup_create` | Crear backup incremental | Hooks |
| `analyze_structure` | Búsqueda AST con ast-grep | Claude |

## Base de datos

```
~/.claude-backup/sessions.db
├── sessions_fts (FTS5)     # Búsqueda full-text
├── backups                  # Tracking de backups
└── swarm_tasks_fts (FTS5)  # Tareas de swarm
```

## Hooks integrados

### SessionEnd (`~/.claude/hooks/session-end-backup.sh`)

```bash
#!/bin/bash
# Delega procesamiento al MCP
input=$(cat)
SESSION_ID=$(echo "$input" | jq -r '.session_id')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path')
CWD=$(echo "$input" | jq -r '.cwd')

~/.claude/hooks/call-mcp-session-save.js "$SESSION_ID" "$TRANSCRIPT_PATH" "$CWD"
```

### PreCompact (`~/.claude/hooks/pre-compact-backup.sh`)

Mismo formato - guarda sesión antes de /compact.

## Metadata guardada

Cada sesión genera dos archivos:

```
~/.claude-backup/{proyecto}/
├── {session_id}.jsonl  # Transcript completo
└── {session_id}.json   # Metadata
```

**Metadata JSON:**
```json
{
  "session_id": "abc123",
  "project": "MiProyecto",
  "timestamp_start": "2026-02-03T10:00:00Z",
  "timestamp_end": "2026-02-03T12:00:00Z",
  "timestamp_start_spain": "03/02/2026 11:00:00",
  "timestamp_end_spain": "03/02/2026 13:00:00",
  "git_branch": "main",
  "edited_files": ["src/app.ts", "README.md"],
  "read_files": ["package.json"],
  "bash_commands": ["npm test", "git status"],
  "tool_counts": "Edit: 15, Read: 10, Bash: 8",
  "first_topic": "Primer mensaje del usuario",
  "last_topic": "Último mensaje del usuario"
}
```

## Scripts útiles

### Reindexar sesiones huérfanas

```bash
~/.claude/scripts/reindex-sessions.sh [proyecto]
```

## Configuración

Registrado en `~/.claude.json`:

```json
{
  "mcpServers": {
    "session-manager": {
      "command": "node",
      "args": ["~/.claude/mcp-servers/session-manager/dist/index.js"],
      "env": {
        "SESSION_DB_PATH": "~/.claude-backup/sessions.db",
        "BACKUP_DIR": "~/.claude-backup"
      }
    }
  }
}
```

## Compilar cambios

```bash
cd ~/.claude/mcp-servers/session-manager
npm run build
# Reiniciar Claude Code para cargar cambios
```

## Beneficios vs hooks bash/jq

| Aspecto | Hooks bash | MCP TypeScript |
|---------|------------|----------------|
| Líneas de código | 250 | 40 (hooks) + 300 (MCP) |
| Mantenibilidad | Difícil | Fácil |
| Debugging | Logs dispersos | Centralizado |
| Ahorro contexto | ~0% | ~95% |
| Extensibilidad | Limitada | Alta |

## Ejemplo de uso

```typescript
// Buscar sesiones
session_search({ query: "refactorizar MCP", filters: { project: "ClaudeLearn" }})

// Listar recientes
session_list({ filters: { project: "ClaudeLearn", limit: 10 }})

// Cargar contexto
session_get_context({ session_id: "abc123", include: { files: true, git_state: true }})
```
