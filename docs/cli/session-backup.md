# Sistema de Backup Resiliente de Sesiones

Sistema independiente de backup para sesiones de Claude Code con captura resiliente y búsqueda FTS5.

## Motivación

**Problemas del sistema oficial:**
- `sessions-index.json` puede corromperse/vaciarse
- `--resume` a veces no encuentra sesiones
- `cleanupPeriodDays` elimina sesiones antiguas
- Dependencia total de `~/.claude/projects/`

**Solución:**
- Backup completo en ubicación propia (`~/.claude-backup/`)
- Captura resiliente (PostToolUse + SessionEnd)
- Búsqueda FTS5 (sin workers, sin overhead)

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│ Durante sesión (PostToolUse hook)                           │
├─────────────────────────────────────────────────────────────┤
│ Cada tool execution:                                        │
│   Read, Write, Bash, Edit, Grep...                          │
│              ↓                                               │
│   Append → ~/.claude-backup/{project}/current-session.jsonl │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Al cerrar sesión (SessionEnd hook)                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Renombra current-session.jsonl → {session_id}.jsonl      │
│ 2. Extrae metadata → {session_id}.json                      │
│ 3. Indexa en SQLite FTS5 → sessions.db                      │
└─────────────────────────────────────────────────────────────┘
```

## Storage

```
~/.claude-backup/
├── sessions.db                    # SQLite FTS5 (búsqueda)
├── ClaudeLearn/
│   ├── current-session.jsonl      # Sesión en progreso
│   ├── abc123.jsonl               # Backup completo (herramientas)
│   ├── abc123.json                # Metadata (archivos, branch, topic)
│   └── abc123.jsonl.official      # Transcript oficial (fallback)
└── OtroProyecto/
    └── ...
```

## Hooks

### PostToolUse: Captura incremental

**Archivo:** `~/.claude/hooks/post-tool-backup.sh`

Se dispara después de cada herramienta. Hace append a `current-session.jsonl`.

**Skip list:** AskUserQuestion, TodoWrite, TaskCreate, TaskUpdate, TaskGet, TaskList

### SessionEnd: Finaliza y guarda

**Archivo:** `~/.claude/hooks/session-end-backup.sh`

1. Mueve `current-session.jsonl` → `{session_id}.jsonl`
2. Copia transcript oficial como fallback
3. Extrae metadata (timestamps, branch, files, topic)
4. Llama a script de indexado FTS5

### Indexado FTS5

**Archivo:** `~/.claude/hooks/index-session.sh`

Crea tabla FTS5 si no existe e indexa el contenido de la sesión.

```sql
CREATE VIRTUAL TABLE sessions_fts USING fts5(
  session_id UNINDEXED,
  project UNINDEXED,
  timestamp,
  git_branch,
  content,     -- user messages + tool inputs
  files,       -- archivos editados
  tokenize = 'porter unicode61'
);
```

## Skills

### /continue-dev

Lista sesiones desde backups y permite cargar contexto.

```
Sesiones de ClaudeLearn (backups independientes):
#   Tamaño      Período                  Branch   Archivos
──────────────────────────────────────────────────────────────
1   6.2 MB 🔴   01/02 15:04→16:23       [main]   SKILL.md, hooks.sh
2   3.1 MB ⚠️   01/02 09:13→14:01       [main]   APRENDIZAJE.md

Sesión en progreso:
- current-session.jsonl (142 KB, 18 observations)
  Última herramienta: Write (15:34)
```

### /search-sessions

Búsqueda FTS5 en todas las sesiones.

```bash
/search-sessions hooks authentication
/search-sessions "SessionEnd hook"
/search-sessions error fix
```

**Sintaxis FTS5:**
- `hooks authentication` → AND implícito
- `"SessionEnd hook"` → Frase exacta
- `hook OR backup` → Cualquiera
- `hook*` → Wildcard
- `hook NOT test` → Exclusión

## Configuración

En `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-tool-backup.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-end-backup.sh"
          }
        ]
      }
    ]
  }
}
```

## Migración

Para migrar datos existentes de `~/.claude/session-context/`:

```bash
~/.claude/hooks/migrate-to-backup.sh
```

## Ventajas

| Feature | Sistema oficial | Sistema backup |
|---------|----------------|----------------|
| Independiente de Claude | ❌ | ✅ |
| Captura resiliente | ❌ | ✅ PostToolUse |
| Sobrevive crash | ❌ | ✅ |
| Búsqueda FTS5 | ❌ | ✅ |
| Puedes limpiar ~/.claude/projects/ | ❌ | ✅ |

## Comparativa con Claude-Mem

| Feature | Este sistema | Claude-Mem |
|---------|-------------|------------|
| Setup | 3 hooks bash | Plugin + worker |
| Dependencies | bash, jq, sqlite3 | Node, Bun, ChromaDB |
| Overhead | Bajo (append) | Alto (worker 24/7) |
| Búsqueda | ✅ FTS5 | ✅ FTS5 + ChromaDB |
| Compresión | ❌ | ✅ Claude SDK |
| Auto-inject | ❌ | ✅ SessionStart |
| Web viewer | ❌ | ✅ |

Este sistema es más simple pero cubre las necesidades básicas sin dependencias adicionales.
