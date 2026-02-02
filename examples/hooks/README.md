# Examples: Hooks

Implementaciones de referencia de hooks personalizados.

## Archivos

- `model-router.sh` - Hook UserPromptSubmit que analiza complejidad y recomienda modelo
- `token-warning.sh` - Hook UserPromptSubmit que avisa cuando el contexto supera 75%

**Nota:** Ambos hooks usan el **patrón de stdin compartido** para evitar condición de carrera (ver `docs/hooks/shared-stdin-pattern.md`)

## Contexto

Este directorio contiene versiones de referencia de hooks documentados en `docs/hooks/` y `docs/workflows/`.

**Instalación real:** Los hooks se despliegan en `~/.claude/hooks/` (no aquí).

**Este directorio es solo para versionado** - permite trackear cambios y fixes de los hooks en git.

## Uso

### model-router.sh

```bash
# Copiar a ubicación activa
cp examples/hooks/model-router.sh ~/.claude/hooks/

# Dar permisos de ejecución
chmod +x ~/.claude/hooks/model-router.sh

# Configurar en ~/.claude/settings.json
# Ver docs/workflows/model-router.md para detalles
```

### token-warning.sh

```bash
# Copiar a ubicación activa
cp examples/hooks/token-warning.sh ~/.claude/hooks/

# Dar permisos de ejecución
chmod +x ~/.claude/hooks/token-warning.sh

# Configurar en ~/.claude/settings.json
# Ver docs/workflows/model-router.md para detalles (usa el mismo patrón)
```

## Patrón de Stdin Compartido

**CRÍTICO:** Los hooks `token-warning.sh` y `model-router.sh` usan un patrón de coordinación:

1. **token-warning.sh** (primer hook):
   - Guarda stdin en `/tmp/claude-hook-input-$$`
   - Exporta `HOOK_INPUT=/tmp/claude-hook-input-$$`
   - Lee desde archivo temporal

2. **model-router.sh** (segundo hook):
   - Verifica si `$HOOK_INPUT` existe
   - Lee desde archivo compartido
   - Fallback a stdin si no hay archivo

**Razón:** Evita condición de carrera donde múltiples hooks consumen stdin secuencialmente.

**Documentación completa:** `docs/hooks/shared-stdin-pattern.md`

## Modificaciones

Al editar hooks:
1. Probar cambios localmente en `~/.claude/hooks/`
2. Copiar versión funcional aquí: `cp ~/.claude/hooks/model-router.sh examples/hooks/`
3. Commitear con mensaje descriptivo del cambio
4. Documentar breaking changes en `docs/hooks/` o `docs/workflows/`

**Si editas orden de hooks:** El primer hook DEBE guardar stdin y exportar `HOOK_INPUT`.
