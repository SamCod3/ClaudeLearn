# Optimizando CLAUDE.md para Reducir Consumo de Tokens

## Problema

CLAUDE.md se carga en **cada request**, multiplicando su costo:

```
CLAUDE.md: 95 líneas = 2,800 tokens
Sesión de 50 requests = 2,800 × 50 = 140K tokens overhead
```

## Solución: Modularización con Rules

### Estrategia

1. **CLAUDE.md**: Solo contenido crítico usado en >80% de requests
2. **Rules**: Contexto específico cargado solo cuando es relevante

### Implementación

#### Antes (Monolítico)
```markdown
# ~/.claude/CLAUDE.md (95 líneas, 2.8K tokens)
- Comunicación ✅
- Anti-alucinaciones ✅
- CLI Tools con ejemplos ⚠️
- Plugins detallados ⚠️
- Skills con flags ⚠️
- Workflow de /init ❌ (usado 5% del tiempo)
```

#### Después (Modular)
```markdown
# ~/.claude/CLAUDE.md (44 líneas, 1.3K tokens)
- Comunicación ✅
- Anti-alucinaciones ✅
- CLI Tools (sin ejemplos) ✅
- Agentes básicos ✅

# ~/.claude/rules/plugins-skills.md
# Solo se carga cuando trabajas en .claude/plugins/** o .claude/skills/**
- Plugins detallados
- Skills con flags
- Commands

# ~/.claude/rules/project-init.md
# Solo se carga cuando usas /init o trabajas en .claude/**
- Workflow de inicialización
- Estructura recomendada
```

### Resultado

| Métrica | Antes | Después | Ahorro |
|---------|-------|---------|--------|
| CLAUDE.md | 95 líneas | 44 líneas | **53%** |
| Tokens base | 2,800 | 1,300 | **53%** |
| Sesión 50 req | 140K | 65K | **75K tokens** |

## Principios de Optimización

### 1. Mantener Solo lo Crítico

**Criterio**: ¿Se usa en >80% de requests?
- ✅ Sí → CLAUDE.md
- ❌ No → Rules específicas

### 2. Eliminar Ejemplos Inline

```markdown
❌ Antes:
- ug (ugrep): búsqueda de texto - comandos útiles:
  - `-w` palabra completa, `-Q` literal, `--bool` búsqueda booleana

✅ Después:
- ug: búsqueda texto (-w, -Q, --bool)
```

**Ahorro**: 60% menos tokens, misma información esencial.

### 3. Condensar Instrucciones

```markdown
❌ Antes (6 líneas):
1. Entender (leer, Explore)
2. Planificar si complejo (Plan)
3. Implementar incrementalmente
4. Verificar (build, tests)
5. Limpiar (code-simplifier si aplica)
6. Al crear subdirs → considerar rule

✅ Después (1 línea):
Entender → Planificar → Implementar → Verificar → Limpiar
```

### 4. Usar Rules con Frontmatter

```yaml
---
paths:
  - ".claude/plugins/**"
  - ".claude/skills/**"
---

# Plugins y Skills
[Detalles solo cuando trabajas aquí]
```

## Checklist de Optimización

- [ ] Identificar secciones usadas <20% del tiempo
- [ ] Mover a rules específicas con frontmatter `paths:`
- [ ] Eliminar ejemplos inline (referenciar docs)
- [ ] Condensar listas largas
- [ ] Mantener solo instrucciones críticas
- [ ] Backup original: `cp CLAUDE.md CLAUDE.md.backup`
- [ ] Verificar en nueva sesión

## Impacto Observado

### Consumo de Tokens

```
Antes de optimización:
  2h → 60% uso (hook + CLAUDE.md verbose)

Después de optimización:
  - Quitado hook PreToolUse force-ugrep.sh
  - CLAUDE.md reducido 53%
  - Esperado: 5-6h → 60% uso
```

### Trade-offs

| Aspecto | Impacto |
|---------|---------|
| **Tokens** | ✅ -53% overhead |
| **Efectividad** | ✅ Igual (info crítica mantenida) |
| **Mantenimiento** | ✅ Más modular |
| **Debugging** | 🟡 Rules pueden no cargar si paths mal configurados |

## Ejemplos de Rules

### Rule para Testing
```yaml
---
paths:
  - "**/__tests__/**"
  - "**/*.test.*"
  - "**/*.spec.*"
---

# Testing Guidelines
- Usar vitest/jest según proyecto
- Coverage >80% para código crítico
- Mock external dependencies
```

### Rule para API
```yaml
---
paths:
  - "src/api/**"
  - "routes/**"
---

# API Guidelines
- Validación de inputs con zod
- Error handling consistente
- Rate limiting en endpoints públicos
```

## Recursos

- [Modular Rules](https://code.claude.com/docs/en/memory#modular-rules-with-clauderules)
- Ejemplo completo: `~/.claude/CLAUDE.md` + `~/.claude/rules/`
