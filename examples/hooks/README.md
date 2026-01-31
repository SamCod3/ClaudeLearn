# Examples: Hooks

Implementaciones de referencia de hooks personalizados.

## Archivos

- `model-router.sh` - Hook UserPromptSubmit que analiza complejidad y recomienda modelo

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

## Modificaciones

Al editar hooks:
1. Probar cambios localmente en `~/.claude/hooks/`
2. Copiar versión funcional aquí: `cp ~/.claude/hooks/model-router.sh examples/hooks/`
3. Commitear con mensaje descriptivo del cambio
4. Documentar breaking changes en `docs/hooks/` o `docs/workflows/`
