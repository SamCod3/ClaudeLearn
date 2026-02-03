# Smart-Ops Rules (OBLIGATORIO)

**Aplica a TODOS los proyectos. Sin excepciones.**

## Regla 1: Archivos Grandes
Archivo >100 líneas:
- ❌ `Read` directo
- ✅ `read_smart mode: summary` PRIMERO
- Ahorro: 70% tokens

## Regla 2: Búsquedas
¿Buscar texto en archivos?
- ❌ `Grep` directo
- ✅ `grep_smart mode: count`
- Después `read_smart mode: grep` si necesitas contenido

## Regla 3: Exploración
¿Explorar proyecto/estructura?
- ❌ Múltiples `Glob` + `Read`
- ✅ `project_overview` (primero)
- ✅ `code_metrics` (para análisis)
- ✅ `diff_smart` (para cambios)

## Regla 4: Orden de Herramientas

```
1. project_overview      ← estructura general
2. read_smart summary    ← peek sin cargar todo
3. grep_smart count      ← contar ocurrencias
4. read_smart grep       ← ver resultados
5. code_metrics          ← analizar código
6. glob_stats            ← metadata archivos
7. diff_smart            ← cambios git
```

## Penalización

Ignorar estas reglas → Wasteado tokens, contexto perdido, usuario pissed off.

## Cuando Esten en Duda

- Archivo grande? → `read_smart summary`
- Buscar? → `grep_smart count`
- Explorar? → `project_overview`

**Simple. No hay excusas.**
