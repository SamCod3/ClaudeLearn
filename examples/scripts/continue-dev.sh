#!/bin/bash
# continue-dev.sh - Listar y cargar contexto de sesiones anteriores
# Uso: continue-dev.sh [--load <session_id>]
set -uo pipefail

PROJECT_NAME=$(basename "$PWD")
BACKUP_DIR="$HOME/.claude-backup/$PROJECT_NAME"
SESSION_ID=""

# Parsear argumentos
while [ $# -gt 0 ]; do
  case "$1" in
    --load) SESSION_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Modo: cargar sesión específica
if [ -n "$SESSION_ID" ]; then
  METADATA="$BACKUP_DIR/${SESSION_ID}.json"
  if [ -f "$METADATA" ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "CONTEXTO DE SESION: $SESSION_ID"
    echo "════════════════════════════════════════════════════════════"
    jq -r '
      "Fin: \(.timestamp_end // "?")" ,
      "Branch: \(.git_branch // "?")" ,
      "" ,
      "Archivos editados:" ,
      (.edited_files // [] | map("- " + .) | .[]),
      "" ,
      "Ultimo tema: \(.last_topic // "-")"
    ' "$METADATA"
    echo "════════════════════════════════════════════════════════════"
  else
    echo "Metadata no encontrada para: $SESSION_ID"
  fi
  exit 0
fi

# Modo: listar sesiones
if [ ! -d "$BACKUP_DIR" ]; then
  echo "No hay backups para: $PROJECT_NAME"
  exit 0
fi

echo "Sesiones de $PROJECT_NAME:"
echo ""
printf "%-40s %8s  %-16s  %-10s  %s\n" "SESSION_ID" "SIZE" "FECHA" "BRANCH" "ARCHIVOS"
echo "────────────────────────────────────────────────────────────────────────────────────────────"

COUNT=0
for f in $(/bin/ls -t "$BACKUP_DIR"/*.jsonl 2>/dev/null | grep -v "current-session.jsonl" | head -10); do
  [ -f "$f" ] || continue
  id=$(basename "$f" .jsonl)
  SIZE_KB=$(($(stat -f "%z" "$f" 2>/dev/null || echo 0) / 1024))

  META="$BACKUP_DIR/${id}.json"
  if [ -f "$META" ]; then
    DATE=$(jq -r '.timestamp_end // ""' "$META" 2>/dev/null | sed 's/T/ /' | cut -c1-16) || DATE="-"
    BRANCH=$(jq -r '.git_branch // ""' "$META" 2>/dev/null) || BRANCH="-"
    FILES=$(jq -r '.edited_files[]? // empty' "$META" 2>/dev/null | awk -F/ '{print $NF}' | head -2 | paste -sd ',' - 2>/dev/null) || true
  else
    DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null) || DATE="-"
    BRANCH="-"
    FILES="-"
  fi

  [ -z "$FILES" ] && FILES="-"
  [ -z "$BRANCH" ] && BRANCH="-"
  printf "%-40s %6s KB  %-16s  %-10s  %s\n" "$id" "$SIZE_KB" "$DATE" "[$BRANCH]" "$FILES"
  COUNT=$((COUNT + 1))
done

if [ $COUNT -eq 0 ]; then
  echo "(No hay sesiones finalizadas)"
fi

# Sesión actual
CURRENT="$BACKUP_DIR/current-session.jsonl"
if [ -f "$CURRENT" ]; then
  LINES=$(wc -l < "$CURRENT" | tr -d ' ')
  SIZE_KB=$(($(stat -f "%z" "$CURRENT" 2>/dev/null || echo 0) / 1024))
  echo ""
  echo "Sesion en progreso: $LINES tool calls ($SIZE_KB KB)"
fi
