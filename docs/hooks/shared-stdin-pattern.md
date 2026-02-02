# Shared Stdin Pattern for Hooks

## Problema

Cuando múltiples hooks en el mismo evento (por ejemplo `UserPromptSubmit`) intentan leer stdin:

```bash
# Hook 1
preview=$(head -c 500)
rest=$(cat)

# Hook 2
preview=$(head -c 500)  # ← stdin ya fue consumido por Hook 1
rest=$(cat)             # ← nada que leer
```

**Resultado:** Condición de carrera, JSON inválido, hook error intermitente.

## Solución: Archivo Temporal Compartido

El **primer hook** guarda stdin en archivo temporal y exporta la ruta. Los **siguientes hooks** leen del archivo.

### Implementación

#### Hook 1 (Primer hook en la cadena)

```bash
#!/bin/bash
trap 'exit 0' ERR

# Guardar stdin en archivo temporal compartido
HOOK_INPUT="/tmp/claude-hook-input-$$"
cat > "$HOOK_INPUT"

# Exportar ruta para hooks siguientes
export HOOK_INPUT

# Leer desde archivo (no stdin)
preview=$(head -c 500 "$HOOK_INPUT")
INPUT_SIZE=$(wc -c < "$HOOK_INPUT" | tr -d ' ')

# ... procesamiento ...

exit 0
```

#### Hook 2+ (Hooks subsecuentes)

```bash
#!/bin/bash
trap 'exit 0' ERR

# Verificar si hay input compartido
if [[ -n "$HOOK_INPUT" && -f "$HOOK_INPUT" ]]; then
  # Leer desde archivo compartido
  preview=$(head -c 500 "$HOOK_INPUT")
else
  # Fallback: leer stdin (compatibilidad)
  preview=$(head -c 500)
  rest=$(cat)
  full_input="${preview}${rest}"
  HOOK_INPUT=$(mktemp)
  trap 'rm -f "$HOOK_INPUT" 2>/dev/null; exit 0' EXIT
  echo "$full_input" > "$HOOK_INPUT"
fi

# Procesar desde archivo
INPUT_SIZE=$(wc -c < "$HOOK_INPUT" | tr -d ' ')

# ... procesamiento ...

exit 0
```

## Ventajas

✅ **Elimina condición de carrera** - Cada hook lee independientemente
✅ **Compatibilidad** - Fallback a stdin si no hay archivo compartido
✅ **Extensible** - N hooks pueden usar el mismo archivo
✅ **Performance** - Overhead I/O insignificante (<1ms para inputs típicos)
✅ **Separación de responsabilidades** - Cada hook mantiene su lógica

## Desventajas

⚠️ **Coordinación requerida** - Variable de entorno `$HOOK_INPUT`
⚠️ **Cleanup manual** - Archivos temporales persisten después de la sesión
⚠️ **PID único** - Usa `$$` para evitar colisiones entre procesos

## Limpieza

Los archivos temporales no se limpian automáticamente. Agregar cleanup periódico:

```bash
# Limpiar archivos temporales de hooks antiguos (>1 día)
find /tmp -name "claude-hook-input-*" -mtime +1 -delete
```

**Opción:** Agregar a hook `SessionEnd` para limpiar archivos de la sesión actual.

## Casos de Uso

Este patrón es útil para:

- **UserPromptSubmit** - Múltiples hooks analizan el mismo prompt
- **PreToolUse** - Validadores y monitores que necesitan el mismo input
- **PostToolUse** - Agregadores y loggers que procesan el mismo output

## Ejemplo Real: token-warning.sh + model-router.sh

**Antes (con race condition):**
- `token-warning.sh` lee stdin → `head -c 500` + `cat`
- `model-router.sh` lee stdin → ❌ stdin vacío, error intermitente

**Después (con archivo compartido):**
- `token-warning.sh` guarda stdin → `/tmp/claude-hook-input-12345`
- `token-warning.sh` exporta → `HOOK_INPUT=/tmp/claude-hook-input-12345`
- `model-router.sh` lee → `head -c 500 "$HOOK_INPUT"` ✅

## Performance

Mediciones en MacBook Pro M1:

```bash
# Sin archivo compartido (lectura directa de stdin)
time (echo "test" | ./hook1.sh && echo "test" | ./hook2.sh)
# real: 0.015s

# Con archivo compartido
time (echo "test" | ./hook1.sh; ./hook2.sh)
# real: 0.017s

# Overhead: +2ms (insignificante)
```

## Referencias

- Implementación: `~/.claude/hooks/token-warning.sh` (primer hook)
- Implementación: `~/.claude/hooks/model-router.sh` (segundo hook)
- Issue: UserPromptSubmit intermittent error (solved)
- Fecha: 2026-02-02
