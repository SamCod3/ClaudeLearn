---
paths:
  - "examples/proxy/**"
---

# Examples: Auto-Router Proxy

Implementación de referencia del proxy que cambia automáticamente entre haiku/sonnet/opus.

## Archivos

- `router.js` - Proxy HTTP que intercepta requests y modifica el modelo según contexto

## Contexto

Este directorio contiene la versión de referencia del proxy documentado en `docs/workflows/auto-router-proxy.md`.

**Instalación real:** El proxy se despliega en `~/.claude/proxy/router.js` (no aquí).

**Este directorio es solo para versionado** - permite trackear cambios y fixes del proxy en git.

## Modificaciones

Al editar `router.js`:
1. Probar cambios localmente en `~/.claude/proxy/`
2. Copiar versión funcional aquí: `cp ~/.claude/proxy/router.js examples/proxy/`
3. Commitear con mensaje descriptivo del cambio
4. Documentar breaking changes en `docs/workflows/auto-router-proxy.md`
