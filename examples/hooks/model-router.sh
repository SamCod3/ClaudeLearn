#!/bin/bash
# model-router.sh - Analiza complejidad y recomienda modelo
# Basado en oh-my-claudecode, adaptado a ES/EN

# Siempre salir con éxito incluso si hay errores
trap 'exit 0' ERR

input=$(cat)

# Early exit si input es muy grande (>50KB)
# Evita timeout con textos largos (copy/paste de artículos, docs, etc)
INPUT_SIZE=$(echo "$input" | wc -c | tr -d ' ')
[[ $INPUT_SIZE -gt 50000 ]] && exit 0

PROMPT=$(echo "$input" | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')

# Si no hay prompt, salir
[[ -z "$PROMPT" ]] && exit 0

# Limitar análisis a primeros 5000 chars (suficiente para detectar keywords)
PROMPT=$(echo "$PROMPT" | head -c 5000)

# Keywords por categoria (bilingue ES/EN)
ARCH_KEYWORDS="refactor|redesign|restructure|architecture|refactorizar|refactorizacion|rediseña|rediseñar|reestructurar|desacoplar|modularizar"
DEBUG_KEYWORDS="debug|root cause|investigate|trace|depurar|investigar|investiga|por que no funciona|por que falla|causa raiz|no funciona|analizar"
RISK_KEYWORDS="production|critical|security|migration|deploy|produccion|critico|urgente|seguridad|migracion|desplegar|peligroso"
SIMPLE_KEYWORDS="find|search|list|where is|what is|show|buscar|busca|encontrar|listar|mostrar|donde esta|que es|dame"

# Detectar señales
HAS_ARCH=$(echo "$PROMPT" | grep -qE "$ARCH_KEYWORDS" && echo 1 || echo 0)
HAS_DEBUG=$(echo "$PROMPT" | grep -qE "$DEBUG_KEYWORDS" && echo 1 || echo 0)
HAS_RISK=$(echo "$PROMPT" | grep -qE "$RISK_KEYWORDS" && echo 1 || echo 0)
HAS_SIMPLE=$(echo "$PROMPT" | grep -qE "$SIMPLE_KEYWORDS" && echo 1 || echo 0)

# Contar palabras (prompts largos = mas complejos)
WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')

# Calcular tier
TIER="MEDIUM"
REASON=""

# HIGH: riesgo, o arquitectura+debug, o muy largo con arquitectura
if [[ "$HAS_RISK" == "1" ]]; then
    TIER="HIGH"
    REASON="Riesgo detectado (produccion/seguridad/migracion)"
elif [[ "$HAS_ARCH" == "1" && "$HAS_DEBUG" == "1" ]]; then
    TIER="HIGH"
    REASON="Refactor + debugging"
elif [[ "$HAS_ARCH" == "1" && "$WORD_COUNT" -gt 50 ]]; then
    TIER="HIGH"
    REASON="Arquitectura compleja ($WORD_COUNT palabras)"
# LOW: solo si tiene keywords simples explicitamente Y es corto
elif [[ "$HAS_SIMPLE" == "1" && "$HAS_ARCH" == "0" && "$HAS_DEBUG" == "0" && "$HAS_RISK" == "0" && "$WORD_COUNT" -lt 15 ]]; then
    TIER="LOW"
    REASON="Tarea simple (busqueda/listado)"
fi

# Solo mostrar si no es MEDIUM (default asumido)
if [[ "$TIER" != "MEDIUM" ]]; then
    MODEL="sonnet"
    [[ "$TIER" == "HIGH" ]] && MODEL="opus"
    [[ "$TIER" == "LOW" ]] && MODEL="haiku"

    jq -n --arg ctx "[Router] Recomendado: $MODEL - $REASON" \
        '{"hookSpecificOutput":{"additionalContext":$ctx}}'
fi

exit 0
