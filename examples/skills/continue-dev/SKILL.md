---
name: continue-dev
description: Cargar contexto de sesión anterior del proyecto actual
allowed-tools: Read, Bash, Glob
---

Listar sesiones anteriores del proyecto actual y cargar el contexto de la que el usuario elija.

## Paso 1: Obtener sesiones del proyecto

Ejecuta este comando para listar las sesiones:

```bash
CWD_ENCODED=$(echo "$PWD" | sed 's|/|-|g' | sed 's|^-||')
SESSIONS_DIR="$HOME/.claude/projects/-$CWD_ENCODED"
PROJECT_NAME=$(basename "$PWD")
CONTEXT_DIR="$HOME/.claude/session-context"

# Verificar directorio existe
if [ ! -d "$SESSIONS_DIR" ]; then
  echo "No hay sesiones para este proyecto"
  exit 0
fi

# Obtener session_id actual (más reciente) - usar /bin/ls para evitar alias
CURRENT_SESSION=$(/bin/ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.jsonl//')

# Variables para totales
TOTAL_SIZE=0
TOTAL_COUNT=0

for f in $(/bin/ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null); do
  [ -f "$f" ] || continue
  id=$(basename "$f" .jsonl)
  [ "$id" = "$CURRENT_SESSION" ] && continue

  # Tamaño del .jsonl (stat es instantáneo)
  SIZE_BYTES=$(stat -f "%z" "$f" 2>/dev/null || echo 0)
  SIZE_KB=$((SIZE_BYTES / 1024))

  # Warning según tamaño
  if [ $SIZE_KB -gt 5120 ]; then
    SIZE_WARN="🔴"
    SIZE_HUMAN="$((SIZE_KB / 1024)) MB"
  elif [ $SIZE_KB -gt 2048 ]; then
    SIZE_WARN="⚠️"
    SIZE_HUMAN="$((SIZE_KB / 1024)) MB"
  elif [ $SIZE_KB -gt 1024 ]; then
    SIZE_WARN="  "
    SIZE_HUMAN="$((SIZE_KB / 1024)) MB"
  else
    SIZE_WARN="  "
    SIZE_HUMAN="${SIZE_KB} KB"
  fi

  # Buscar session-context (ya parseado por hook SessionEnd)
  CONTEXT_FILE="$CONTEXT_DIR/${PROJECT_NAME}-${id}.json"

  if [ -f "$CONTEXT_FILE" ]; then
    # Usar session-context (rápido, ya parseado)
    BRANCH=$(jq -r '.git_branch // "?"' "$CONTEXT_FILE" 2>/dev/null)
    DATE_RAW=$(jq -r '.timestamp_start // ""' "$CONTEXT_FILE" 2>/dev/null)
    FILES=$(jq -r '.edited_files[]?' "$CONTEXT_FILE" 2>/dev/null | xargs -I{} basename {} 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')

    # Formatear fecha
    if [ -n "$DATE_RAW" ]; then
      DATE_FMT=$(echo "$DATE_RAW" | cut -dT -f1,2 | sed 's/T/ /' | cut -d: -f1,2)
    else
      DATE_FMT=$(stat -f "%Sm" -t "%d/%m %H:%M" "$f" 2>/dev/null)
    fi
  else
    # Fallback: solo stat (sin parsear .jsonl)
    BRANCH="?"
    DATE_FMT=$(stat -f "%Sm" -t "%d/%m %H:%M" "$f" 2>/dev/null)
    FILES="-"
  fi

  TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  printf "%s | %7s %s | %s | [%s] | %s\n" "$id" "$SIZE_HUMAN" "$SIZE_WARN" "$DATE_FMT" "$BRANCH" "$FILES"
done

# Mostrar total
if [ $TOTAL_COUNT -gt 0 ]; then
  TOTAL_MB=$((TOTAL_SIZE / 1048576))
  echo ""
  echo "Total: $TOTAL_COUNT sesiones (${TOTAL_MB} MB)"
fi
```

## Paso 2: Mostrar menú

Presenta las sesiones en formato tabla:

```
Sesiones de {proyecto}:
#   Tamaño      Fecha        Branch   Archivos
─────────────────────────────────────────────────────────
1   6 MB 🔴    01/02 15:04  [main]   SKILL.md, check.sh
2   3 MB ⚠️    01/02 15:01  [main]   APRENDIZAJE-COMPLETO.md
3   1 MB       31/01 22:12  [main]   hooks.md, chris-dunlop...
4   365 KB     01/02 15:59  [main]   -

Total: 4 sesiones (11 MB)

¿Cuál sesión quieres cargar?
```

**Leyenda warnings:**
- 🔴 >5 MB (puede causar lentitud en startup)
- ⚠️ >2 MB (considerar limpiar)

Usa AskUserQuestion para que el usuario elija.

## Paso 3: Cargar contexto

Una vez el usuario elija, carga el session-context:

```bash
PROJECT_NAME=$(basename "$PWD")
CONTEXT_FILE="$HOME/.claude/session-context/${PROJECT_NAME}-${id}.json"

if [ -f "$CONTEXT_FILE" ]; then
  jq '.' "$CONTEXT_FILE"
else
  echo "No hay session-context para esta sesión"
fi
```

## Paso 4: Mostrar contexto con encabezado claro

```
════════════════════════════════════════════════════════════
CONTEXTO DE SESIÓN ANTERIOR
Inicio: {timestamp_start} → Fin: {timestamp_end}
Branch: {git_branch}
Tamaño: {size} {warning si aplica}
════════════════════════════════════════════════════════════

Archivos editados:
- {archivo1}
- {archivo2}
...

Último tema: {last_topic}

════════════════════════════════════════════════════════════
FIN CONTEXTO ANTERIOR
════════════════════════════════════════════════════════════
```

## Paso 5: Ofrecer continuar

Pregunta: "¿Quieres que lea alguno de estos archivos para continuar?"

Si el usuario dice sí, lee los archivos relevantes.

## Dependencias

Este skill funciona mejor con el hook `SessionEnd` configurado:
- Hook: `~/.claude/hooks/session-end-save.sh`
- Guarda: session-context con git_branch, edited_files, timestamps, last_topic

Sin el hook, solo muestra tamaño y fecha (sin archivos editados ni branch).
