#!/bin/bash
# model-router.sh - Analiza complejidad y recomienda modelo
# Patrón: lee desde archivo temporal compartido por token-warning.sh

# Siempre salir con éxito ante cualquier error
trap 'exit 0' ERR

# Verificar si hay input compartido (del primer hook)
if [[ -n "$HOOK_INPUT" && -f "$HOOK_INPUT" ]]; then
  # Leer desde archivo compartido
  preview=$(head -c 500 "$HOOK_INPUT")
else
  # Fallback: leer stdin (no debería ocurrir si token-warning.sh ejecuta primero)
  preview=$(head -c 500)

  # Early exits tempranos
  [[ "$preview" == *"base64"* ]] && exit 0
  [[ "$preview" == *"data:image"* ]] && exit 0
  [[ "$preview" == *"image/png"* ]] && exit 0
  [[ "$preview" == *"image/jpeg"* ]] && exit 0

  # Leer resto y crear archivo temporal
  rest=$(cat)
  full_input="${preview}${rest}"
  HOOK_INPUT=$(mktemp)
  trap 'rm -f "$HOOK_INPUT" 2>/dev/null; exit 0' EXIT
  echo "$full_input" > "$HOOK_INPUT"
fi

# Early exit si detecta contenido problemático (imágenes base64)
[[ "$preview" == *"base64"* ]] && exit 0
[[ "$preview" == *"data:image"* ]] && exit 0
[[ "$preview" == *"image/png"* ]] && exit 0
[[ "$preview" == *"image/jpeg"* ]] && exit 0

# Debug log (solo si pasó el filtro)
exec 2>/tmp/model-router-debug.log

# Obtener tamaño del input
INPUT_SIZE=$(wc -c < "$HOOK_INPUT" | tr -d ' ')
echo "Input size: $INPUT_SIZE" >&2

# Early exit si muy grande
if [[ $INPUT_SIZE -ge 60000 ]]; then
    echo "Early exit: too large" >&2
    exit 0
fi

# Extraer prompt con jq
PROMPT=$(jq -r '.prompt // "" | .[0:5000] | ascii_downcase' < "$HOOK_INPUT" 2>/dev/null || echo "")
echo "Prompt length: ${#PROMPT}" >&2

[[ -z "$PROMPT" ]] && exit 0

# Keywords
ARCH_KEYWORDS="refactor|redesign|restructure|architecture|refactorizar|refactorizacion|rediseña|rediseñar|reestructurar|desacoplar|modularizar"
DEBUG_KEYWORDS="debug|root cause|investigate|trace|depurar|investigar|investiga|por que no funciona|por que falla|causa raiz|no funciona|analizar"
RISK_KEYWORDS="production|critical|security|migration|deploy|produccion|critico|urgente|seguridad|migracion|desplegar|peligroso"
SIMPLE_KEYWORDS="find|search|list|where is|what is|show|buscar|busca|encontrar|listar|mostrar|donde esta|que es|dame"

HAS_ARCH=$(grep -qE "$ARCH_KEYWORDS" <<< "$PROMPT" && echo 1 || echo 0)
HAS_DEBUG=$(grep -qE "$DEBUG_KEYWORDS" <<< "$PROMPT" && echo 1 || echo 0)
HAS_RISK=$(grep -qE "$RISK_KEYWORDS" <<< "$PROMPT" && echo 1 || echo 0)
HAS_SIMPLE=$(grep -qE "$SIMPLE_KEYWORDS" <<< "$PROMPT" && echo 1 || echo 0)

WORD_COUNT=$(wc -w <<< "$PROMPT" | tr -d ' ')

TIER="MEDIUM"
REASON=""

if [[ "$HAS_RISK" == "1" ]]; then
    TIER="HIGH"
    REASON="Riesgo detectado"
elif [[ "$HAS_ARCH" == "1" && "$HAS_DEBUG" == "1" ]]; then
    TIER="HIGH"
    REASON="Refactor + debugging"
elif [[ "$HAS_ARCH" == "1" && "$WORD_COUNT" -gt 50 ]]; then
    TIER="HIGH"
    REASON="Arquitectura compleja"
elif [[ "$HAS_SIMPLE" == "1" && "$HAS_ARCH" == "0" && "$HAS_DEBUG" == "0" && "$HAS_RISK" == "0" && "$WORD_COUNT" -lt 15 ]]; then
    TIER="LOW"
    REASON="Tarea simple"
fi

echo "Tier: $TIER, Reason: $REASON" >&2

if [[ "$TIER" != "MEDIUM" ]]; then
    MODEL="sonnet"
    [[ "$TIER" == "HIGH" ]] && MODEL="opus"
    [[ "$TIER" == "LOW" ]] && MODEL="haiku"
    jq -n --arg ctx "[Router] Recomendado: $MODEL - $REASON" '{"hookSpecificOutput":{"additionalContext":$ctx}}'
fi

exit 0
