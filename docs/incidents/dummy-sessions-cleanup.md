# Incident: Sesiones Dummy Creadas Accidentalmente

**Fecha:** 2026-02-03
**Duración:** ~5 horas (10:25 → 16:43 CET)
**Impacto:** 33 sesiones dummy en DB + 66 archivos innecesarios
**Estado:** ⚠️ **PARCIALMENTE RESUELTO - PROBLEMA PERSISTENTE**

## Síntomas

Después de implementar smart-compact + session-manager integration (sesión 50919210), se detectaron múltiples sesiones con:
- Duración: **1ms** (timestamp_start == timestamp_end)
- Sin archivos editados, lecturas, o comandos bash
- `git_branch: "unknown"` (indicador de creación incompleta)
- Sin resumen disponible

**Rangos de dummies encontrados:**
- 16:22:56 - 16:22:59 (17 sesiones)
- 10:26:00 - 10:26:04 (16 sesiones)

## Causa Raíz

`session-save.ts` (línea 84-91) aceptaba transcripts vacíos y los indexaba como sesiones válidas:

```typescript
const transcript = lines.map(line => {
  try {
    return JSON.parse(line);
  } catch {
    return null;
  }
}).filter(Boolean);  // ← Puede resultar en array vacío []

// Se indexaba aunque transcript estuviera vacío ❌
```

Cuando se indexaba un transcript vacío:
- Metadata se creaba con todos los campos vacíos
- Sesión se guardaba en DB con UUID pero sin contenido
- `git_branch` resultaba en "unknown" (no se extraía del transcript vacío)

**Origen probable:** SessionStart hook o testing del script reindex-sessions.sh disparaban `session_save` sin transcript válido.

## Limpieza Realizada

### 1. Eliminar sesiones dummy de la DB ✅
```bash
DELETE FROM sessions_fts WHERE session_id IN (
  'facd805c-4aab-45aa-a899-e3a588f1a180',
  'f05639e7-5cdf-4b92-9718-559bdfcf2bb9',
  ... (33 total)
)
```

**Resultado:**
- 33 registros eliminados de sessions_fts
- 66 archivos JSONL + JSON eliminados de ~/.claude-backup/ClaudeLearn/
- DB limpiada: 0 sesiones con git_branch="unknown"

### 2. Agregar validación en session-save.ts ✅

**Cambio:**
```typescript
// 3.5 VALIDACIÓN: Rechazar transcripts vacíos
if (transcript.length === 0) {
  console.log(`[session-save] Skipping empty session: ${args.session_id}`);
  // Eliminar archivo vacío que se copió
  await fs.promises.unlink(backupFile);
  return {
    content: [{
      type: "text",
      text: JSON.stringify({
        skipped: true,
        reason: "Empty transcript",
        session_id: args.session_id,
        lines: lines.length
      })
    }]
  };
}
```

**Prevención:**
- Sesiones vacías retornan `{ skipped: true }`
- Archivo JSONL vacío se elimina automáticamente
- Log claro: `[session-save] Skipping empty session`
- No se indexa nada en DB

### 3. Recompilar MCP server ✅

```bash
cd ~/.claude/mcp-servers/session-manager
npm run build  # ✅ Sin errores
```

## Verificación Post-Limpieza

### Antes:
```
Total sesiones: 52
Con git_branch="unknown": 33 (dummies)
```

### Después:
```
Total sesiones: 19
Con git_branch="unknown": 0 ✅
Sesiones reales intactas:
  - 50919210 (362 mensajes) ✅
  - 507c0f9b (con contenido) ✅
```

## Cómo Evitar en el Futuro

1. **MCP previene automáticamente** empty transcripts (ya implementado)
2. **Revisar hooks de SessionStart** para no disparar session_save sin transcript
3. **Logs monitoreados:** Si ves logs `[session-save] Skipping empty session`, investigar por qué se dispara

## Archivos Modificados

- `~/.claude/mcp-servers/session-manager/src/tools/session-save.ts` (+28 líneas validación)
- `~/.claude-backup/sessions.db` (limpieza de 33 registros)
- `~/.claude-backup/ClaudeLearn/` (eliminación de 66 archivos)

## ⚠️ PROBLEMA PERSISTENTE

Después de la limpieza inicial, **más dummies siguen siendo creados** en rangos similares:
- Lote 1: 16:22:56-16:22:59 ✅ LIMPIADO
- Lote 2: 10:26:00-10:26:04 ✅ LIMPIADO
- Lote 3: 10:25:57-10:25:59 ✅ LIMPIADO
- Lote 4: Nueva detección (fecha desconocida) - CONTINÚA

**Posibles causas a investigar:**
1. Hook de SessionStart/SessionInit sin transcript válido
2. MCP session_list creando entradas temporales
3. Script de migración/reindex con loop infinito
4. CloudPunk/autosave disparándose sin control

**Acción requerida:**
- [ ] Revisar logs del MCP server (`stderr` de la inicialización)
- [ ] Monitorear eventos de SessionStart
- [ ] Agregar logging a `indexInFTS5` para ver cuándo se crea cada sesión
- [ ] Considerar deshabilitar hooks de SessionStart hasta encontrar la causa

## Lecciones Aprendidas

✅ Validar entrada en MCP tools (nunca asumir transcripts válidos)
✅ Agregar logs claros para debugging de creación de sesiones
✅ Considerar duración < 100ms como indicador de sesión incompleta
⚠️ **ISSUE PENDIENTE**: Encontrar root cause del patrón persistente de creación de dummies
