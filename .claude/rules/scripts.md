---
paths:
  - "examples/scripts/**"
---
# Scripts Standalone

Scripts bash que contienen lógica de skills para reducir consumo de contexto.

## Patron

- Skills en `~/.claude/skills/` solo invocan estos scripts
- Scripts hacen todo el trabajo y devuelven output formateado
- Reduccion: ~85-90% menos contexto por invocacion

## Scripts disponibles

- `search-sessions.sh` - Busqueda FTS5 en sesiones
- `continue-dev.sh` - Listar y cargar contexto de sesiones

## Instalacion

```bash
cp examples/scripts/*.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh
```
