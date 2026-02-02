# Search Tools

Herramientas CLI para búsqueda de código, preferibles sobre herramientas internas de Claude.

## Problema

Claude Code tiene herramientas internas (Grep, Glob) que usan ripgrep por debajo, pero:
- **Mucho ruido** en resultados (matches irrelevantes)
- **Sin búsqueda booleana** nativa
- **Sin búsqueda estructural** (busca texto, no sintaxis)

## Solución

Usar herramientas CLI especializadas vía Bash:

| Herramienta | Propósito | Ventaja sobre Grep interno |
|-------------|-----------|---------------------------|
| **ugrep** | Búsqueda de texto | Menos ruido, búsqueda booleana, mejor UX |
| **ast-grep** | Búsqueda estructural | Busca por sintaxis AST, 0 falsos positivos |
| **fd** | Búsqueda de archivos | Más rápido y limpio que find |

## ugrep (búsqueda de texto)

### Instalación
```bash
brew install ugrep
```

### Uso básico
```bash
# Búsqueda simple
ug "pattern" --include='*.ts'

# Palabra completa
ug -w "exact_word"

# Búsqueda literal (sin regex)
ug -Q "exact.string.with.dots"

# Búsqueda booleana
ug --bool "error AND critical"
ug --bool "bug OR issue"

# Con contexto
ug "pattern" -C2  # 2 líneas antes/después

# Contar matches
ug "pattern" -c

# Solo nombres de archivo
ug "pattern" -l
```

### Ventajas sobre ripgrep
- ✅ Mejor formato de output
- ✅ Búsqueda booleana nativa (`--bool`)
- ✅ Búsqueda literal más clara (`-Q`)
- ✅ Mejor manejo de Unicode
- ✅ Más opciones de contexto

## ast-grep (búsqueda estructural)

### Instalación
```bash
brew install ast-grep
```

### Uso básico
```bash
# Buscar funciones (no strings que contienen "function")
ast-grep --pattern 'function $NAME($$$)' --lang ts

# Buscar condicionales específicos
ast-grep --pattern 'if ($COND) { $$$ }' --lang bash

# Buscar imports
ast-grep --pattern 'import { $$$ } from "$MOD"' --lang ts

# Solo archivos que coinciden
ast-grep --pattern 'class $NAME { $$$ }' -l
```

### Ventajas
- ✅ **0 falsos positivos** (busca AST, no texto)
- ✅ No encuentra comentarios ni strings
- ✅ Entiende estructura de código
- ✅ Soporta múltiples lenguajes

## Comparación

### Ejemplo: Buscar "session"

**ripgrep/Grep (ruidoso):**
```bash
rg "session" --type sh
# Encuentra:
# - get_session_stats (nombre de función)
# - sessions_file (variable)
# - "session" en comentarios
# - "session" en strings
# = 500+ resultados
```

**ugrep (más limpio):**
```bash
ug -w "session" --include='*.sh'
# Encuentra solo "session" como palabra independiente
# = 20 resultados relevantes
```

**ast-grep (preciso):**
```bash
ast-grep --pattern 'session' --lang bash
# Encuentra solo referencias de código válidas
# = 5 resultados exactos
```

## Configuración para Claude Code

### 1. Documentar en CLAUDE.md

```markdown
## CLI Tools
- **ug** (ugrep): búsqueda de texto - PREFERIR sobre Grep interno
  - `-w` palabra completa, `-Q` literal, `--bool` búsqueda booleana
- **ast-grep**: búsqueda estructural de código (sintaxis, no texto)
  - `--pattern 'function $NAME($$$)'` busca por AST
- **rg** (ripgrep): fallback si ugrep no es apropiado
- **fd**: búsqueda de archivos - PREFERIR sobre Glob
```

### 2. Hook PreToolUse (NO recomendado)

⚠️ **Advertencia sobre overhead:**

Los hooks PreToolUse se ejecutan ANTES de cada tool use. En sesiones largas con muchas herramientas (50+ tool uses), el overhead acumulativo aumenta significativamente el consumo de tokens.

**Ejemplo de hook (no usar en producción):**
```bash
#!/bin/bash
input=$(cat)
tool=$(echo "$input" | jq -r '.tool // empty')

if [ "$tool" = "Grep" ]; then
  echo "💡 Recordatorio: usar Bash con 'ug' (ugrep)"
fi
```

**Problema:**
- 50 tool uses × hook = 50 ejecuciones
- Cada ejecución añade contexto
- Consumo de tokens 2-3x mayor

**Mejor alternativa:** Confiar solo en CLAUDE.md (sin hooks).

### 3. Resultado

Con solo CLAUDE.md (sin hooks):
- **CLAUDE.md** → Instruye a Claude a usar `ug`
- **Sin overhead** → Zero tokens extras por tool use
- **Efectividad**: ~90% de uso automático (suficiente)

## Recursos

- [ugrep GitHub](https://github.com/Genivia/ugrep)
- [ast-grep](https://ast-grep.github.io/)
- [fd](https://github.com/sharkdp/fd)
