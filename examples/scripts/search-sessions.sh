#!/bin/bash
# search-sessions.sh - Buscar en sesiones usando FTS5
# Uso: search-sessions.sh <query> [--all] [--project <nombre>]
set -euo pipefail

DB_PATH="$HOME/.claude-backup/sessions.db"
PROJECT_FILTER=""
FILTER_MODE="current"
QUERY=""

# Verificar DB
if [ ! -f "$DB_PATH" ]; then
  echo "No hay sesiones indexadas."
  exit 0
fi

# Parsear argumentos
while [ $# -gt 0 ]; do
  case "$1" in
    --all) FILTER_MODE="all"; shift ;;
    --project) FILTER_MODE="specific"; PROJECT_FILTER="$2"; shift 2 ;;
    *) QUERY="$QUERY $1"; shift ;;
  esac
done

QUERY=$(echo "$QUERY" | xargs)
if [ -z "$QUERY" ]; then
  echo "Uso: search-sessions.sh <query> [--all] [--project <nombre>]"
  exit 1
fi

[ "$FILTER_MODE" = "current" ] && PROJECT_FILTER=$(basename "$PWD")
QUERY=$(echo "$QUERY" | sed "s/'/''/g")

# Construir WHERE
case "$FILTER_MODE" in
  "all") WHERE_CLAUSE="WHERE content MATCH '$QUERY'" ;;
  *) WHERE_CLAUSE="WHERE content MATCH '$QUERY' AND project = '$PROJECT_FILTER'" ;;
esac

# Header
case "$FILTER_MODE" in
  "all") echo "Busqueda en TODOS los proyectos" ;;
  "specific") echo "Busqueda en proyecto: $PROJECT_FILTER" ;;
  *) echo "Busqueda en proyecto actual: $PROJECT_FILTER" ;;
esac
echo "Query: \"$QUERY\""
echo ""

# Query adaptativa
if [ "$FILTER_MODE" = "all" ]; then
  sqlite3 "$DB_PATH" -header -column <<EOF
SELECT
  substr(session_id,1,8)||'...' as session,
  project,
  substr(timestamp,1,10) as date,
  git_branch as branch,
  snippet(sessions_fts,4,'**','**','...',60) as match
FROM sessions_fts
$WHERE_CLAUSE
ORDER BY rank
LIMIT 15;
EOF
else
  sqlite3 "$DB_PATH" -header -column <<EOF
SELECT
  substr(session_id,1,8)||'...' as session,
  substr(timestamp,1,10) as date,
  git_branch as branch,
  snippet(sessions_fts,4,'**','**','...',60) as match
FROM sessions_fts
$WHERE_CLAUSE
ORDER BY rank
LIMIT 15;
EOF
fi
