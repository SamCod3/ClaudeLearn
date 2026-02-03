# Session Migration: Agregar is_pre_compact a sesiones antiguas

## Problema

Después de implementar smart-compact + session-manager integration, las **sesiones antiguas NO tienen el flag `is_pre_compact`** en su metadata.

Esto significa:
- Sesiones futuras (post-implementación): tendrán el flag ✅
- Sesiones antiguas (pre-implementación): no lo tendrán ❌

## Solución: Script reindex-sessions.sh

Existe un script en `~/.claude/scripts/reindex-sessions.sh` que:
1. Busca todas las sesiones JSONL antiguas del proyecto
2. Verifica cuáles NO están en la DB
3. Reindexan llamando al MCP con metadata actualizada

### Actualización del Script

El script ha sido actualizado para:
- Pasar parámetro `trigger="session-end"` al reindexar
- Esto hace que el MCP agregue `is_pre_compact: false` (por defecto)
- Las sesiones antiguas ahora son "session-end" triggers, que NO tienen pre-compact

### Ejecución

```bash
# Reindexar proyecto actual
~/.claude/scripts/reindex-sessions.sh

# O especificar proyecto
~/.claude/scripts/reindex-sessions.sh ClaudeLearn
```

### Resultado

```
Indexadas: 17
Ya existían: 42
================================
```

Esto indexó sesiones que estaban huérfanas en `~/.claude/projects/{CWD}/*.jsonl` pero no estaban en la DB de sesiones.

## Comportamiento Después

### Sesiones Antiguas
- `is_pre_compact: false` (agregado por migración)
- `/continue-dev` las ve como "normales"
- Se comportan igual que antes

### Sesiones Nuevas (Post-Implementación)
- Si compactadas: `is_pre_compact: true`, `timestamp_compact` set
- Si normales: `is_pre_compact: false` (default)
- `/continue-dev` prioriza correctamente

## Verificación

Ver que sesiones están indexadas:

```bash
sqlite3 ~/.claude-backup/sessions.db \
  "SELECT session_id, is_pre_compact FROM sessions_fts LIMIT 10;"
```

Buscar sesiones compactadas:

```bash
sqlite3 ~/.claude-backup/sessions.db \
  "SELECT session_id, timestamp_start FROM sessions_fts WHERE is_pre_compact = 1 LIMIT 10;"
```

## Nota

- El script solo reindexan sesiones "huérfanas" (las que no estaban en la DB)
- Sesiones ya indexadas se saltan
- Si necesitas re-indexar todo, elimina la DB y corre el script:
  ```bash
  rm ~/.claude-backup/sessions.db
  ~/.claude/scripts/reindex-sessions.sh ClaudeLearn
  ```

## Resumen

✅ Sesiones antiguas migradas y tienen `is_pre_compact` en metadata
✅ Se comportan como "normales" (no compactadas)
✅ `/continue-dev` ahora funciona con todo el historial
✅ Sistema forward-compatible con futuras sesiones compactadas
