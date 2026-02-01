---
name: search-sessions
description: Buscar en sesiones anteriores usando FTS5
allowed-tools: Bash, Read
---

Buscar en las sesiones guardadas usando SQLite FTS5.

## Uso

El usuario proporciona una query de búsqueda. Ejemplos:

```
/search-sessions hooks authentication
/search-sessions "SessionEnd hook"
/search-sessions error fix
```

## Paso 1: Verificar base de datos

```bash
DB_PATH="$HOME/.claude-backup/sessions.db"

if [ ! -f "$DB_PATH" ]; then
  echo "No hay sesiones indexadas todavía."
  echo "La base de datos se creará cuando finalice una sesión."
  exit 0
fi

# Verificar que la tabla existe
TABLE_EXISTS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions_fts';" 2>/dev/null)

if [ -z "$TABLE_EXISTS" ]; then
  echo "La tabla FTS5 no existe todavía."
  echo "Se creará cuando finalice una sesión con el hook SessionEnd."
  exit 0
fi
```

## Paso 2: Ejecutar búsqueda

Reemplaza `{QUERY}` con la query del usuario:

```bash
DB_PATH="$HOME/.claude-backup/sessions.db"
QUERY="{QUERY}"

sqlite3 "$DB_PATH" -header -column <<EOF
SELECT
  substr(session_id, 1, 8) || '...' as session,
  project,
  substr(timestamp, 1, 10) as date,
  git_branch as branch,
  snippet(sessions_fts, 4, '**', '**', '...', 60) as match
FROM sessions_fts
WHERE content MATCH '$QUERY'
ORDER BY rank
LIMIT 15;
EOF
```

## Paso 3: Mostrar resultados

Presenta los resultados con formato:

```
Búsqueda: "{query}"

session   project       date        branch  match
--------  -----------   ----------  ------  ------------------------------------------------
abc123..  ClaudeLearn   2026-02-01  main    ...configurar **SessionEnd hook** en settings...
def456..  OtroProj      2026-01-30  feat    Implementar sistema de **hooks** para backup...

(15 resultados)
```

## Paso 4: Ofrecer cargar sesión

Pregunta al usuario:

```
¿Quieres cargar el contexto de alguna sesión?
Indica el session_id o número de la lista.
```

Si el usuario indica una sesión, usa el comando:

```bash
PROJECT="ClaudeLearn"  # Extraer del resultado
SESSION_ID="abc123..."  # Completar con el ID real
METADATA="$HOME/.claude-backup/$PROJECT/${SESSION_ID}.json"

if [ -f "$METADATA" ]; then
  jq '.' "$METADATA"
else
  echo "Metadata no encontrada"
fi
```

## Sintaxis avanzada FTS5

Ejemplos de queries FTS5:

- `hooks authentication` - Busca ambas palabras (AND implícito)
- `"SessionEnd hook"` - Busca frase exacta
- `hook OR backup` - Busca cualquiera de las palabras
- `hook*` - Busca palabras que empiecen con "hook"
- `hook NOT test` - Busca "hook" pero no "test"
- `NEAR(hook backup, 5)` - Palabras a máximo 5 palabras de distancia

## Dependencias

Requiere el sistema de backup con indexado FTS5:
- Hook SessionEnd: `~/.claude/hooks/session-end-backup.sh`
- Script indexado: `~/.claude/hooks/index-session.sh`
- Base de datos: `~/.claude-backup/sessions.db`

Sin sesiones indexadas, la búsqueda no devolverá resultados.
