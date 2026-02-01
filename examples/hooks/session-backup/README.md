# Sistema de Backup Resiliente para Claude Code

Backup independiente de sesiones con búsqueda FTS5.

## Requisitos

- macOS o Linux
- `jq` instalado (`brew install jq` o `apt install jq`)
- `sqlite3` (pre-instalado en macOS/Linux)

## Instalación Rápida

```bash
# 1. Copiar scripts a ~/.claude/hooks/
cp index-session.sh ~/.claude/hooks/
cp session-end-backup.sh ~/.claude/hooks/
cp post-tool-backup.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# 2. Configurar hooks en settings.json
# Añadir a ~/.claude/settings.json:
```

```json
{
  "hooks": {
    "PostToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/post-tool-backup.sh"
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-end-backup.sh"
      }]
    }]
  }
}
```

```bash
# 3. Migrar sesiones existentes
./migrate-all-projects.sh
```

## Scripts Incluidos

| Script | Propósito |
|--------|-----------|
| `migrate-all-projects.sh` | Migración masiva desde ~/.claude/projects/ |
| `index-session.sh` | Indexa sesión en SQLite FTS5 |
| `session-end-backup.sh` | Hook SessionEnd - finaliza y guarda |
| `post-tool-backup.sh` | Hook PostToolUse - captura incremental |

## Uso

```bash
# Preview de migración
./migrate-all-projects.sh --dry-run

# Migrar todo
./migrate-all-projects.sh

# Migrar proyecto específico
./migrate-all-projects.sh --project MiProyecto

# Forzar reindexado
./migrate-all-projects.sh --force
```

## Estructura Resultante

```
~/.claude-backup/
├── sessions.db              ← SQLite FTS5
├── MiProyecto/
│   ├── abc123.jsonl         ← Transcript completo
│   ├── abc123.json          ← Metadata
│   └── current-session.jsonl ← Sesión en progreso
└── OtroProyecto/
    └── ...
```

## Skills Complementarios

Copiar a `~/.claude/skills/`:

- `continue-dev/` - Listar y cargar sesiones anteriores
- `search-sessions/` - Búsqueda FTS5 en todas las sesiones

## Verificación

```bash
# Contar sesiones indexadas
sqlite3 ~/.claude-backup/sessions.db "SELECT COUNT(*) FROM sessions_fts;"

# Buscar
sqlite3 ~/.claude-backup/sessions.db "SELECT project, session_id FROM sessions_fts WHERE content MATCH 'hooks';"
```
