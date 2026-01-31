# Model Router - Recomendador de Modelos

Hook preventivo que analiza cada prompt y recomienda el modelo optimo (haiku/sonnet/opus) basandose en la complejidad detectada.

Inspirado en [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode), adaptado para Claude Code vanilla con keywords bilingues ES/EN.

## Como funciona

```
Tu prompt → model-router.sh → Analiza keywords → Calcula tier → Muestra recomendacion
```

### Tiers y modelos

| Tier | Modelo | Cuando |
|------|--------|--------|
| LOW | haiku | Busquedas, listados, preguntas simples |
| MEDIUM | sonnet | Tareas normales (no muestra nada) |
| HIGH | opus | Arquitectura, debugging, riesgo |

### Salida

Solo muestra mensaje si detecta LOW o HIGH:

```
[Router] Recomendado: opus - Riesgo detectado (produccion/seguridad/migracion)
[Router] Recomendado: haiku - Tarea simple (busqueda/listado)
```

## Keywords detectadas (bilingue ES/EN)

### Arquitectura → HIGH

```
refactor, redesign, restructure, architecture
refactorizar, refactorizacion, rediseña, rediseñar, reestructurar, desacoplar, modularizar
```

### Debugging → contribuye a HIGH

```
debug, root cause, investigate, trace
depurar, investigar, investiga, por que no funciona, por que falla, causa raiz, no funciona, analizar
```

### Riesgo → HIGH

```
production, critical, security, migration, deploy
produccion, critico, urgente, seguridad, migracion, desplegar, peligroso
```

### Simple → LOW

```
find, search, list, where is, what is, show
buscar, busca, encontrar, listar, mostrar, donde esta, que es, dame
```

## Reglas de decision

```
1. Riesgo detectado                    → HIGH (opus)
2. Arquitectura + Debugging            → HIGH (opus)
3. Arquitectura + prompt largo (>50w)  → HIGH (opus)
4. Simple + corto (<15w) sin complej.  → LOW (haiku)
5. Default                             → MEDIUM (sonnet) - no muestra nada
```

## Ejemplos

| Prompt | Tier | Modelo |
|--------|------|--------|
| "busca los archivos .ts" | LOW | haiku |
| "donde esta el config" | LOW | haiku |
| "añade un boton de logout" | MEDIUM | sonnet (no muestra) |
| "implementa el formulario de contacto" | MEDIUM | sonnet (no muestra) |
| "refactorizar el sistema de auth" | MEDIUM | sonnet (solo arch, no risk) |
| "refactorizar el sistema en produccion" | HIGH | opus |
| "por que falla el login" | MEDIUM | sonnet (solo debug) |
| "investiga por que falla y refactoriza" | HIGH | opus |

## Instalacion

### 1. Crear el hook

```bash
# El script esta en ~/.claude/hooks/model-router.sh
chmod +x ~/.claude/hooks/model-router.sh
```

### 2. Configurar en settings.json

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/model-router.sh" }
        ]
      }
    ]
  }
}
```

## Limitaciones

- **No cambia el modelo automaticamente** - Claude Code vanilla no permite esto
- Solo es informativo/preventivo
- El usuario debe cambiar manualmente:
  - Reiniciar con `claude --model opus`
  - O usar `/model opus` dentro de la sesion (si disponible)

## Personalizacion

Para añadir mas keywords, edita `~/.claude/hooks/model-router.sh`:

```bash
# Añadir nuevas keywords de arquitectura
ARCH_KEYWORDS="refactor|...|mi-nueva-keyword"
```

## Codigo fuente original

Ver implementacion completa de oh-my-claudecode:
- [router.ts](https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/src/features/model-routing/router.ts)
- [signals.ts](https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/src/features/model-routing/signals.ts)
- [rules.ts](https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/src/features/model-routing/rules.ts)
