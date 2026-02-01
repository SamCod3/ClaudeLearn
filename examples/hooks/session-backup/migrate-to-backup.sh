#!/bin/bash
# Script de migración: Migra session-context y .jsonl existentes al nuevo sistema
# Uso: ~/.claude/hooks/migrate-to-backup.sh

OLD_CONTEXT_DIR="$HOME/.claude/session-context"
NEW_BACKUP_DIR="$HOME/.claude-backup"

echo "=== Migración de sesiones al sistema de backup ==="
echo ""

# Crear directorio de backup
mkdir -p "$NEW_BACKUP_DIR"

MIGRATED_COUNT=0
JSONL_COPIED=0

# Iterar sobre archivos de context existentes
for ctx in "$OLD_CONTEXT_DIR"/*.json; do
  [ -f "$ctx" ] || continue

  # Extraer project y session_id del filename
  filename=$(basename "$ctx" .json)

  # Formato: {PROJECT_NAME}-{SESSION_ID}.json
  # Extraer project (todo antes del último -)
  # Extraer session_id (después del último -)

  # Para manejar projects con guiones, usamos el patrón de UUID
  if [[ "$filename" =~ ^(.+)-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$ ]]; then
    project="${BASH_REMATCH[1]}"
    session_id="${BASH_REMATCH[2]}"
  else
    # Fallback: asumir que el project es la primera parte
    project="${filename%-*}"
    session_id="${filename##*-}"
  fi

  # Crear directorio del proyecto
  mkdir -p "$NEW_BACKUP_DIR/$project"

  # Copiar metadata
  cp "$ctx" "$NEW_BACKUP_DIR/$project/${session_id}.json"

  # Intentar copiar .jsonl oficial si existe
  CWD=$(jq -r '.cwd // ""' "$ctx" 2>/dev/null)
  if [ -n "$CWD" ]; then
    CWD_ENCODED=$(echo "$CWD" | sed 's|/|-|g' | sed 's|^-||')
    OLD_JSONL="$HOME/.claude/projects/-$CWD_ENCODED/${session_id}.jsonl"

    if [ -f "$OLD_JSONL" ]; then
      cp "$OLD_JSONL" "$NEW_BACKUP_DIR/$project/${session_id}.jsonl"
      JSONL_COPIED=$((JSONL_COPIED + 1))

      # Indexar en FTS5
      if [ -f "$HOME/.claude/hooks/index-session.sh" ]; then
        "$HOME/.claude/hooks/index-session.sh" "$session_id" "$project" "$NEW_BACKUP_DIR/$project/${session_id}.jsonl" 2>/dev/null
      fi
    fi
  fi

  MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
  echo "✓ Migrado: $project / ${session_id:0:8}..."
done

echo ""
echo "=== Migración completa ==="
echo "Metadata migradas: $MIGRATED_COUNT"
echo "JSONL copiados: $JSONL_COPIED"
echo ""
echo "Los datos están en: $NEW_BACKUP_DIR"
echo ""
echo "Nota: Los archivos originales en ~/.claude/session-context/ no se eliminaron."
echo "Puedes eliminarlos manualmente con: rm -rf ~/.claude/session-context/"
