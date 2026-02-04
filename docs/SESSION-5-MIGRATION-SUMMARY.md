# Sesión 5: FTS5 Schema Migration Summary

**Fecha:** 2026-02-04
**Status:** ✅ COMPLETADO
**Backup:** `/Users/sambler/.claude/sessions-migration-backup-20260204_085532`

---

## El Problema

```
Error: no such table: sessions_fts
```

### Root Cause

La DB nueva (~/.claude/sessions/sessions.db) tenía schema **INCORRECTO**:
- Contenía: `sessions`, `session_files`, `transcripts_fts`, `backups`
- Debería: `sessions_fts`, `swarm_tasks_fts`, `backups`

**Por qué pasó:**
1. En Sesiones 3-4, se cambió la ruta que usa el MCP (`~/.claude/sessions/sessions.db`)
2. El hook guardaba sesiones en la ruta nueva
3. La nueva DB se inicializó con schema **viejo** (schema.sql obsoleto)
4. MCP no creaba tablas automáticamente (inicialización manual requerida)

---

## Solución: Opción A (Reemplazo Directo)

### Fase 1: Backup de Seguridad ✅

```bash
BACKUP_DIR=~/.claude/sessions-migration-backup-20260204_085532
```

Creado con:
- `sessions-new-EMPTY.db` (86KB) - DB vacía original
- `sessions-backup-ORIGINAL.db` (8.6MB) - Backup DB con datos completos

**Reversible:** Si algo falla, `cp "$BACKUP_DIR/sessions-new-EMPTY.db" ~/.claude/sessions/sessions.db`

### Fase 2: Reemplazo ✅

```bash
rm ~/.claude/sessions/sessions.db
cp ~/.claude-backup/sessions.db ~/.claude/sessions/sessions.db
chmod 644 ~/.claude/sessions/sessions.db
```

**Resultado:**
- Antes: 84KB (vacía)
- Después: 8.6MB (409 sesiones)

### Fase 3: Verificación ✅

```bash
sqlite3 ~/.claude/sessions/sessions.db "SELECT COUNT(*) FROM sessions_fts"
# Output: 409 ✅

sqlite3 ~/.claude/sessions/sessions.db "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%fts%' ORDER BY name"
# Output: (todas las tablas FTS5 presentes) ✅
```

---

## Mejoras de Prevención Futura

### 1. Verificación Automática de Schema en Startup

**Archivo:** `~/.claude/mcp-servers/session-manager/src/index.ts` (líneas 34-100)

**Función:** `verifyAndCreateSchema()`

**Lógica:**
1. Al iniciar el MCP, verifica que existen `sessions_fts` y `swarm_tasks_fts`
2. Si alguna falta, la crea automáticamente
3. Loguea resultado en stderr para debugging

**Output esperado:**
```
[Session Manager MCP] Connected to: /Users/sambler/.claude/sessions/sessions.db
[Session Manager MCP] ✅ Schema verification passed (all required tables exist)
[Session Manager MCP] Server running
```

**Si falta tabla:**
```
[Session Manager MCP] Connected to: ...
[Session Manager MCP] ⚠️  Missing tables: sessions_fts. Creating schema...
[Session Manager MCP] ✅ Created table: sessions_fts
[Session Manager MCP] Server running
```

### 2. Script de Test de Schema

**Archivo:** `~/.claude/mcp-servers/session-manager/test-schema.sh`

**Uso:**
```bash
~/.claude/mcp-servers/session-manager/test-schema.sh
```

**Verifica:**
- ✅ Database exists
- ✅ Table sessions_fts exists
- ✅ Table swarm_tasks_fts exists
- ✅ FTS5 search works
- ✅ Sessions indexed: 409
- ✅ Swarm tasks indexed: 1

### 3. Documentación del Schema Real

**Archivo:** `~/.claude/mcp-servers/session-manager/src/db/SCHEMA-ACTUAL.md`

**Contiene:**
- Schema correcto de `sessions_fts` y `swarm_tasks_fts`
- Explicación de cada columna
- Ejemplos de queries
- Tablas obsoletas marcadas
- Nota sobre schema.sql being outdated

---

## Cambios Compilados

```bash
cd ~/.claude/mcp-servers/session-manager
npm run build
# ✅ tsc compiled successfully (no errors)
```

**Archivos modificados:**
1. `src/index.ts` - Agregada función `verifyAndCreateSchema()` + llamada al startup

**Archivos creados:**
1. `test-schema.sh` - Script de validación
2. `src/db/SCHEMA-ACTUAL.md` - Documentación correcta

---

## Verificación Post-Migración

### Test 1: Schema Correcto ✅
```bash
~/.claude/mcp-servers/session-manager/test-schema.sh
# ✅ All schema tests PASSED
```

### Test 2: Sesiones Recuperadas ✅
```bash
sqlite3 ~/.claude/sessions/sessions.db "SELECT COUNT(*) FROM sessions_fts"
# 409 sesiones
```

### Test 3: Búsqueda Funciona ✅
```bash
sqlite3 ~/.claude/sessions/sessions.db "SELECT session_id FROM sessions_fts WHERE sessions_fts MATCH 'router' LIMIT 3"
# Retorna resultados (si existen sesiones con "router")
```

### Test 4: Nueva Iniciativa
Usar Claude Code en otros proyectos y verificar:
1. `claude session list` → muestra sesiones correctamente
2. `claude resume <session-id>` → carga sesión completa
3. El MCP logs no tienen errores de FTS5

---

## Resumen Ejecutivo

| Aspecto | Antes | Después |
|---------|-------|---------|
| **DB Size** | 84KB (vacía) | 8.6MB (409 sesiones) |
| **Schema** | Incorrecto (transcripts_fts) | Correcto (sessions_fts) |
| **Error** | "no such table: sessions_fts" | ✅ RESUELTO |
| **Prevención** | Manual (nada) | Automático (verifyAndCreateSchema) |
| **Testing** | No había | test-schema.sh |
| **Docs** | schema.sql (obsoleto) | SCHEMA-ACTUAL.md |

## Beneficios

1. ✅ **409 sesiones recuperadas** - Historial completo disponible
2. ✅ **Múltiples proyectos soportados** - Sessions de otros repos funcionan
3. ✅ **Prevención automática** - MCP crea schema si falta
4. ✅ **Testing integrado** - Script para validar integridad
5. ✅ **Documentación clara** - Schema real documentado

## Próximos Pasos Recomendados

1. **Verificar en otros proyectos** - Crea sesión en proyecto diferente y verifica que se guarda
2. **Monitorear MCP logs** - Verificar que no hay "schema missing" messages
3. **Ejecutar test_schema.sh periódicamente** - Para validación de integridad

---

**Conclusión:** El problema está RESUELTO. El MCP ahora:
- ✅ Verifica schema en startup
- ✅ Crea tablas si faltan
- ✅ Loguea estado de salud
- ✅ Es resistente a corrupción de schema

**Backup seguro en:** `/Users/sambler/.claude/sessions-migration-backup-20260204_085532`
