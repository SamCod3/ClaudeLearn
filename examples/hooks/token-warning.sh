#!/bin/bash
# Aviso de tokens al enviar mensaje
# Patrón: archivo temporal compartido para evitar condición de carrera

# Siempre salir con éxito ante cualquier error
trap 'exit 0' ERR

# Guardar stdin en archivo temporal compartido
HOOK_INPUT="/tmp/claude-hook-input-$$"
cat > "$HOOK_INPUT"

# Exportar ruta para hooks siguientes
export HOOK_INPUT

# Leer preview desde archivo
preview=$(head -c 500 "$HOOK_INPUT")

# Early exit si detecta contenido problemático (imágenes base64)
[[ "$preview" == *"base64"* ]] && exit 0
[[ "$preview" == *"data:image"* ]] && exit 0
[[ "$preview" == *"image/png"* ]] && exit 0
[[ "$preview" == *"image/jpeg"* ]] && exit 0

# Debug log (solo si pasó el filtro)
exec 2>/tmp/token-warning-debug.log

# Obtener tamaño del input
INPUT_SIZE=$(wc -c < "$HOOK_INPUT" | tr -d ' ')
echo "Input size: $INPUT_SIZE" >&2

# Early exit si muy grande
if [[ $INPUT_SIZE -ge 60000 ]]; then
    echo "Early exit: too large" >&2
    exit 0
fi

# Usar jq para extraer porcentaje de contexto
USED_PCT=$(jq -r '.context_window.used_percentage // 0' < "$HOOK_INPUT" 2>/dev/null | cut -d'.' -f1 || echo "0")
echo "Used PCT: $USED_PCT" >&2

THRESHOLD=75

if [[ "$USED_PCT" =~ ^[0-9]+$ ]] && [ "$USED_PCT" -ge "$THRESHOLD" ]; then
    echo "⚠️  Contexto al ${USED_PCT}% - considera /smart-compact"
fi

exit 0
