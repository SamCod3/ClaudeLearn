# Troubleshooting Hooks

Guía para diagnosticar y solucionar problemas con hooks de Claude Code.

## Error: "UserPromptSubmit hook error"

### Síntomas

- Error aparece intermitentemente al enviar mensajes
- Puede ocurrir con mensajes simples o complejos
- El error no es consistente (a veces funciona, a veces no)

### Causas Comunes

#### 1. Condición de Carrera en stdin

**Problema:** Múltiples hooks leen stdin secuencialmente, causando que el segundo hook reciba stdin vacío.

**Solución:** Usar patrón de archivo temporal compartido (ver `shared-stdin-pattern.md`)

**Implementado en:**
- `~/.claude/hooks/token-warning.sh` (primer hook)
- `~/.claude/hooks/model-router.sh` (segundo hook)

#### 2. Timeout en procesamiento JSON

**Problema:** Input muy grande causa que `jq` tarde demasiado en parsear.

**Solución:** Early exit para inputs >60KB:

```bash
INPUT_SIZE=$(wc -c < "$HOOK_INPUT" | tr -d ' ')
if [[ $INPUT_SIZE -ge 60000 ]]; then
    echo "Early exit: too large" >&2
    exit 0
fi
```

#### 3. Imágenes base64 en input

**Problema:** Input contiene imágenes codificadas en base64 (>1MB), causando timeout.

**Solución:** Early exit al detectar imágenes en primeros 500 bytes:

```bash
preview=$(head -c 500 "$HOOK_INPUT")

[[ "$preview" == *"base64"* ]] && exit 0
[[ "$preview" == *"data:image"* ]] && exit 0
[[ "$preview" == *"image/png"* ]] && exit 0
[[ "$preview" == *"image/jpeg"* ]] && exit 0
```

#### 4. JSON inválido

**Problema:** Claude Code pasa JSON malformado ocasionalmente.

**Solución:** Trap de errores y fallback:

```bash
trap 'exit 0' ERR

PROMPT=$(jq -r '.prompt // ""' < "$HOOK_INPUT" 2>/dev/null || echo "")
```

## Diagnóstico

### Paso 1: Verificar logs de hooks

```bash
# Ver logs de token-warning
tail -20 /tmp/token-warning-debug.log

# Ver logs de model-router
tail -20 /tmp/model-router-debug.log

# Seguir logs en tiempo real
tail -f /tmp/token-warning-debug.log /tmp/model-router-debug.log
```

**Buscar:**
- `Input size:` - Tamaño del input procesado
- `Early exit:` - Razón de early exit
- `Used PCT:` - Porcentaje de contexto usado
- `Tier:` - Modelo recomendado

### Paso 2: Probar hooks individualmente

```bash
# Deshabilitar todos los hooks UserPromptSubmit
jq '.hooks.UserPromptSubmit = []' ~/.claude/settings.json > /tmp/settings.json
mv /tmp/settings.json ~/.claude/settings.json

# Reiniciar Claude Code
# Enviar mensaje → ¿error desaparece?
```

Si el error desaparece, el problema es en los hooks. Habilitar uno a uno:

```bash
# Habilitar SOLO token-warning.sh
cat ~/.claude/settings.json | jq '.hooks.UserPromptSubmit = [{
  "hooks": [{
    "type": "command",
    "command": "~/.claude/hooks/token-warning.sh"
  }]
}]' > /tmp/settings.json
mv /tmp/settings.json ~/.claude/settings.json

# Reiniciar y probar
# Si falla → problema en token-warning.sh
# Si funciona → agregar model-router.sh y probar de nuevo
```

### Paso 3: Verificar archivo compartido

```bash
# Agregar debug al inicio de model-router.sh
echo "HOOK_INPUT: $HOOK_INPUT" >&2
echo "File exists: $(test -f "$HOOK_INPUT" && echo yes || echo no)" >&2

# Reiniciar Claude Code y enviar mensaje
# Ver logs:
tail /tmp/model-router-debug.log
```

**Esperado:**
```
HOOK_INPUT: /tmp/claude-hook-input-12345
File exists: yes
Input size: 323
```

**Si `File exists: no`** → token-warning.sh no exportó correctamente.

### Paso 4: Simular input de Claude Code

```bash
# Crear JSON de prueba
cat > /tmp/test-input.json <<'EOF'
{
  "prompt": "refactor this code",
  "context_window": {
    "used_percentage": 45.2
  }
}
EOF

# Probar hook manualmente
cat /tmp/test-input.json | ~/.claude/hooks/token-warning.sh
cat /tmp/test-input.json | HOOK_INPUT=/tmp/claude-hook-input-test ~/.claude/hooks/model-router.sh

# Ver output y logs
```

### Paso 5: Verificar permisos

```bash
ls -la ~/.claude/hooks/*.sh

# Debe mostrar: -rwxr-xr-x (ejecutable)
```

Si no son ejecutables:

```bash
chmod +x ~/.claude/hooks/token-warning.sh
chmod +x ~/.claude/hooks/model-router.sh
```

## Soluciones Rápidas

### Solución 1: Deshabilitar hooks temporalmente

```bash
jq '.hooks.UserPromptSubmit = []' ~/.claude/settings.json > /tmp/settings.json
mv /tmp/settings.json ~/.claude/settings.json
```

Restaurar después de debug:

```bash
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

### Solución 2: Usar solo un hook

Si el problema persiste, mantener solo `model-router.sh` (el más importante para el proxy):

```bash
jq '.hooks.UserPromptSubmit = [{
  "hooks": [{
    "type": "command",
    "command": "~/.claude/hooks/model-router.sh"
  }]
}]' ~/.claude/settings.json > /tmp/settings.json
mv /tmp/settings.json ~/.claude/settings.json
```

**Trade-off:** Pierdes aviso de contexto al 75%, pero el routing sigue funcionando.

### Solución 3: Combinar hooks en uno solo

Crear `~/.claude/hooks/combined-hook.sh` que haga ambas tareas (ver plan completo).

## Errores Comunes y Soluciones

### Error: "Permission denied"

```bash
# Verificar permisos
ls -la ~/.claude/hooks/

# Hacer ejecutables
chmod +x ~/.claude/hooks/*.sh
```

### Error: "jq: command not found"

```bash
# Instalar jq
brew install jq
```

### Error: "No such file or directory: /tmp/claude-hook-input-*"

**Causa:** `model-router.sh` ejecuta antes que `token-warning.sh` (orden incorrecto).

**Solución:** Verificar orden en `settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/token-warning.sh"  // ← PRIMERO
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/model-router.sh"   // ← SEGUNDO
          }
        ]
      }
    ]
  }
}
```

### Warning: "Early exit: too large"

**No es error.** El hook detectó input >60KB y salió tempranamente para evitar timeout. Esto es comportamiento esperado.

## Verificación de Integración

### Proxy sigue funcionando

```bash
# Verificar proceso escuchando
lsof -i :3456

# Debe mostrar: node ... router.js
```

```bash
# Ver logs del proxy
tail -f ~/.claude/proxy/router.log

# Buscar: "Routing to opus/sonnet/haiku"
```

### Backup system funciona

```bash
# Verificar que SessionEnd ejecuta
ls -la ~/.claude-backup/ClaudeLearn/*/metadata.json

# Últimas 3 sesiones
ls -lt ~/.claude-backup/ClaudeLearn/ | head -4
```

### Swarm system funciona

```bash
# Verificar base de datos
sqlite3 ~/.claude-swarm/board.db "SELECT COUNT(*) FROM tasks;"

# Verificar sesiones swarm
ls ~/.claude-swarm/sessions/
```

## Performance Benchmarks

### Hooks sin archivo compartido

```bash
time (echo '{"prompt":"test"}' | ~/.claude/hooks/token-warning.sh.bak)
# real: 0.008s
```

### Hooks con archivo compartido

```bash
time (echo '{"prompt":"test"}' | ~/.claude/hooks/token-warning.sh && ~/.claude/hooks/model-router.sh)
# real: 0.010s
```

**Overhead:** +2ms (insignificante)

### Input grande (50KB)

```bash
# Generar input grande
jq -n --arg text "$(head -c 50000 /dev/urandom | base64)" '{prompt:$text}' > /tmp/large-input.json

time (cat /tmp/large-input.json | ~/.claude/hooks/token-warning.sh)
# real: 0.012s (early exit funciona)
```

## Referencias

- Patrón de stdin compartido: `docs/hooks/shared-stdin-pattern.md`
- Proxy auto-router: `docs/workflows/auto-router-proxy.md`
- Hooks generales: `docs/hooks/hooks.md`
- Plan completo: `~/.claude/plans/shimmying-imagining-bunny.md`
- Fecha fix: 2026-02-02
