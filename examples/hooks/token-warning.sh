#!/bin/bash
# Aviso de tokens al enviar mensaje

input=$(cat)

# Early exit si input es muy grande (>50KB)
# Evita timeout con textos largos (copy/paste de artículos, docs, etc)
INPUT_SIZE=$(echo "$input" | wc -c | tr -d ' ')
[[ $INPUT_SIZE -gt 50000 ]] && exit 0

USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d'.' -f1)
THRESHOLD=75

if [ "$USED_PCT" -ge "$THRESHOLD" ]; then
    echo "⚠️  Contexto al ${USED_PCT}% - considera /smart-compact"
fi
