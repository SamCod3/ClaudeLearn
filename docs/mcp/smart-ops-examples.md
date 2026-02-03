# Smart-Ops: Guía de Uso y Ejemplos

Ejemplos prácticos de las funciones MCP para ahorro de tokens (70-90% reducción).

## Tabla de Contenidos

- [read_smart](#read_smart---lectura-inteligente)
- [grep_smart](#grep_smart---búsqueda-agregada)
- [code_metrics](#code_metrics---métricas-de-código)
- [project_overview](#project_overview---vista-general)
- [diff_smart](#diff_smart---comparaciones)
- [glob_stats](#glob_stats---listado-con-metadata)

---

## read_smart - Lectura Inteligente

**Ahorro estimado: 70-99%**

### Modo: summary (resumen inicio/fin)

**Caso de uso:** Ver estructura de archivo grande sin leerlo completo.

```typescript
// ❌ ANTES (2000 tokens)
Read({ file_path: "APRENDIZAJE-COMPLETO.md" })
// Retorna 1516 líneas completas

// ✅ AHORA (100 tokens)
read_smart({
  file_path: "APRENDIZAJE-COMPLETO.md",
  mode: "summary",
  head_lines: 10,
  tail_lines: 10
})
/*
Retorna:
{
  file: "APRENDIZAJE-COMPLETO.md",
  mode: "summary",
  total_lines: 1516,
  returned_lines: 20,
  content: "1: # Título\n2: ...\n10: ---\n--- [1496 lines omitted] ---\n1507: ...\n1516: fin"
}
*/
```

**Ahorro:** 95% (2000 → 100 tokens)

### Modo: lines (rango específico)

**Caso de uso:** Leer solo sección específica de archivo largo.

```typescript
// ✅ Leer líneas 50-100 de log
read_smart({
  file_path: "server.log",
  mode: "lines",
  start_line: 50,
  end_line: 100
})
// Retorna solo 50 líneas vs 5000+ del archivo completo
```

**Ahorro:** 90% en archivos muy largos

### Modo: grep (líneas con patrón)

**Caso de uso:** Ver solo líneas con imports/exports sin leer todo.

```typescript
// ✅ Solo líneas con "export"
read_smart({
  file_path: "src/utils.ts",
  mode: "grep",
  pattern: "^export"
})
// Retorna solo las líneas que empiezan con "export"
```

**Ahorro:** 85% (solo exports vs archivo completo)

### Modo: section (extraer sección markdown)

**Caso de uso:** Leer solo una sección de README/documentación.

```typescript
// ✅ Solo sección "Installation"
read_smart({
  file_path: "README.md",
  mode: "section",
  section_marker: "## Installation"
})
// Retorna solo desde "## Installation" hasta el siguiente header ##
```

**Ahorro:** 80-95% (solo sección vs documento completo)

### Modo: json_path (extraer valor JSON)

**Caso de uso:** Ver solo dependencies sin leer package.json completo.

```typescript
// ✅ Solo dependencies
read_smart({
  file_path: "package.json",
  mode: "json_path",
  json_path: "dependencies"
})
/*
Retorna:
{
  "react": "^18.0.0",
  "typescript": "^5.0.0"
}
*/
```

**Ahorro:** 70-90% (solo campo específico)

---

## grep_smart - Búsqueda Agregada

**Ahorro estimado: 60-80%**

### Modo: count (conteo por archivo)

**Caso de uso:** Ver distribución de TODOs/FIXMEs por archivo.

```typescript
// ❌ ANTES (1500 tokens)
Grep({ pattern: "TODO", output_mode: "content" })
// Retorna todas las líneas con TODO de todos los archivos

// ✅ AHORA (300 tokens)
grep_smart({
  pattern: "TODO",
  mode: "count",
  include: "*.ts",
  path: "src/"
})
/*
Retorna:
{
  total_matches: 47,
  files_with_matches: 8,
  by_file: [
    { file: "src/app.ts", count: 15 },
    { file: "src/utils.ts", count: 8 },
    ...
  ]
}
*/
```

**Ahorro:** 80% (conteo vs líneas completas)

### Modo: files (solo nombres)

**Caso de uso:** Ver qué archivos usan una API sin ver el código.

```typescript
// ✅ Archivos que importan React
grep_smart({
  pattern: "import.*from ['\"]react['\"]",
  mode: "files",
  include: "*.{ts,tsx}"
})
/*
Retorna:
{
  files: [
    "src/App.tsx",
    "src/components/Header.tsx",
    "src/hooks/useAuth.ts"
  ]
}
*/
```

**Ahorro:** 85% (solo nombres vs contenido)

### Modo: first_match (primera ocurrencia)

**Caso de uso:** Ver contexto de cada uso sin duplicados.

```typescript
// ✅ Primera ocurrencia de "export default" por archivo
grep_smart({
  pattern: "export default",
  mode: "first_match",
  include: "*.ts"
})
/*
Retorna solo la primera línea con "export default" de cada archivo
*/
```

**Ahorro:** 70% (una línea por archivo vs todas)

### Modo: stats (estadísticas agregadas)

**Caso de uso:** Análisis de uso de console.log por tipo de archivo.

```typescript
// ✅ Estadísticas de console.log
grep_smart({
  pattern: "console\\.log",
  mode: "stats"
})
/*
Retorna:
{
  total: 127,
  by_extension: {
    ".ts": 45,
    ".js": 82
  },
  by_directory: {
    "src/": 90,
    "tests/": 37
  }
}
*/
```

**Ahorro:** 90% (resumen vs líneas completas)

---

## code_metrics - Métricas de Código

**Ahorro estimado: 80-90%**

### Análisis completo de módulo

**Caso de uso:** Entender estructura de archivo sin leerlo.

```typescript
// ❌ ANTES (800 tokens)
Read({ file_path: "src/router.js" })
// Leer 407 líneas para contar funciones manualmente

// ✅ AHORA (100 tokens)
code_metrics({
  file_path: "src/router.js",
  metrics: ["loc", "functions", "imports", "todos"]
})
/*
Retorna:
{
  file: "src/router.js",
  extension: ".js",
  loc: {
    total_lines: 407,
    code_lines: 297,
    blank_lines: 58,
    comment_lines: 52
  },
  functions: {
    count: 13,
    list: [
      { name: "handleRequest", line: 306 },
      { name: "proxyRequest", line: 337 },
      ...
    ]
  },
  imports: {
    count: 8,
    list: ["express", "axios", ...]
  },
  todos: {
    count: 3,
    list: [
      { line: 39, type: "TODO", text: "Implement retry logic" },
      ...
    ]
  }
}
*/
```

**Ahorro:** 87% (800 → 100 tokens)

### Solo LOC (conteo rápido)

```typescript
// ✅ Solo líneas de código
code_metrics({
  file_path: "src/app.ts",
  metrics: ["loc"]
})
// Retorna solo conteo de líneas sin contenido
```

**Ahorro:** 95% para archivos grandes

### Complejidad ciclomática

```typescript
// ✅ Detectar funciones complejas
code_metrics({
  file_path: "src/validator.ts",
  metrics: ["complexity"]
})
/*
Retorna:
{
  complexity: {
    average: 4.2,
    max: 12,
    complex_functions: [
      { name: "validateSchema", complexity: 12, line: 45 }
    ]
  }
}
*/
```

**Ahorro:** 90% (metadata vs código completo)

---

## project_overview - Vista General

**Ahorro estimado: 90-95%**

### Exploración inicial de proyecto

**Caso de uso:** Entender estructura sin múltiples Glob + Read.

```typescript
// ❌ ANTES (1000+ tokens)
// Múltiples llamadas: Glob("**/*"), Read("package.json"), git log, etc.

// ✅ AHORA (150 tokens)
project_overview({
  path: ".",
  depth: 3,
  include_git_stats: true
})
/*
Retorna:
{
  path: "/Users/user/proyecto",
  structure: {
    ".": { files: 5, dirs: 3 },
    "src": { files: 12, dirs: 2 },
    "src/components": { files: 8, dirs: 0 },
    "src/utils": { files: 4, dirs: 0 }
  },
  largest_files: [
    { path: "dist/bundle.js", size: 2.3MB },
    { path: "src/App.tsx", size: 45KB },
    ...
  ],
  technologies: {
    "TypeScript": ["tsconfig.json", "src/**/*.ts"],
    "React": ["package.json:react"],
    "Node.js": ["package.json:node"]
  },
  git_stats: {
    most_edited: [
      { file: "src/App.tsx", commits: 42 },
      ...
    ]
  }
}
*/
```

**Ahorro:** 85% (1000 → 150 tokens)

### Solo estructura de directorios

```typescript
// ✅ Vista rápida sin git stats
project_overview({
  path: ".",
  depth: 2,
  include_git_stats: false
})
```

**Ahorro:** 90% vs exploración manual

---

## diff_smart - Comparaciones

**Ahorro estimado: 60-80%**

### Solo archivos cambiados

**Caso de uso:** Ver qué cambió sin ver el diff completo.

```typescript
// ❌ ANTES (2000+ tokens)
Bash({ command: "git diff HEAD~5" })
// Retorna diff completo con todas las líneas cambiadas

// ✅ AHORA (400 tokens)
diff_smart({
  mode: "files_only",
  git_ref: "HEAD~5"
})
/*
Retorna:
{
  ref: "HEAD~5",
  changed_files: [
    "src/app.ts",
    "docs/README.md",
    "package.json"
  ]
}
*/
```

**Ahorro:** 80% (2000 → 400 tokens)

### Resumen de cambios

```typescript
// ✅ Cuántas líneas cambiaron por archivo
diff_smart({
  mode: "summary",
  git_ref: "main"
})
/*
Retorna:
{
  ref: "main",
  files: [
    { file: "src/app.ts", added: 45, removed: 12 },
    { file: "README.md", added: 3, removed: 0 }
  ],
  totals: { added: 48, removed: 12 }
}
*/
```

**Ahorro:** 70% (resumen vs diff completo)

### Estadísticas por tipo

```typescript
// ✅ Análisis de cambios por extensión
diff_smart({
  mode: "stats",
  git_ref: "HEAD~10"
})
/*
Retorna:
{
  by_extension: {
    ".ts": { files: 12, added: 234, removed: 89 },
    ".md": { files: 3, added: 45, removed: 12 }
  }
}
*/
```

**Ahorro:** 85% (stats vs diffs completos)

---

## glob_stats - Listado con Metadata

**Ahorro estimado: 50-70%**

### Archivos más grandes

**Caso de uso:** Encontrar archivos grandes sin leerlos.

```typescript
// ❌ ANTES (600 tokens)
Glob({ pattern: "**/*.ts" }) + múltiples stat/wc

// ✅ AHORA (200 tokens)
glob_stats({
  pattern: "**/*.ts",
  sort_by: "size",
  limit: 10,
  include_line_count: true,
  include_first_line: true
})
/*
Retorna:
{
  pattern: "**/*.ts",
  total_files: 45,
  files: [
    {
      path: "src/server.ts",
      size_bytes: 34560,
      size_kb: 34,
      modified: "2026-02-03",
      lines: 892,
      first_line: "import express from 'express';"
    },
    ...
  ]
}
*/
```

**Ahorro:** 67% (600 → 200 tokens)

### Solo tamaños (sin line count)

```typescript
// ✅ Más rápido sin contar líneas
glob_stats({
  pattern: "dist/**/*.js",
  sort_by: "size",
  limit: 20,
  include_line_count: false
})
```

**Ahorro:** 70% + más rápido

### Filtrar por fecha

```typescript
// ✅ Archivos modificados recientemente
glob_stats({
  pattern: "src/**/*.ts",
  sort_by: "date",
  limit: 10
})
// Retorna los 10 archivos modificados más recientemente
```

**Ahorro:** 60% vs leer timestamps manualmente

---

## Métricas Reales de Ahorro

Basadas en uso real en sesiones de desarrollo:

| Tarea típica | Herramientas anteriores | Smart-ops | Tokens antes | Tokens ahora | Ahorro |
|--------------|-------------------------|-----------|--------------|--------------|--------|
| Ver estructura proyecto | 3x Glob, 5x Read | 1x project_overview | 1200 | 150 | 87% |
| Contar TODOs | 1x Grep content | 1x grep_smart count | 1800 | 250 | 86% |
| Analizar imports | 1x Read completo | 1x code_metrics | 900 | 120 | 87% |
| Ver cambios git | 1x git diff | 1x diff_smart | 2500 | 450 | 82% |
| Leer logs parcialmente | 1x Read + manual parse | 1x read_smart summary | 3000 | 180 | 94% |
| Listar archivos grandes | 1x Glob + N stats | 1x glob_stats | 800 | 220 | 72% |

**Promedio general: 84.7% de ahorro**

---

## Cuándo usar cada función

### read_smart
- ✅ Archivos >100 líneas que no necesitas completos
- ✅ Logs, documentación, archivos generados
- ✅ Extraer secciones específicas de markdown
- ✅ Ver valores de JSON/YAML sin todo el archivo
- ❌ Archivos pequeños (<50 líneas) - usar Read normal

### grep_smart
- ✅ Contar ocurrencias, buscar archivos afectados
- ✅ Análisis de uso de APIs/imports
- ✅ Detección de TODOs/FIXMEs distribuidos
- ❌ Buscar código específico para editar - usar Grep normal

### code_metrics
- ✅ Entender estructura sin leer código
- ✅ Contar funciones/imports/LOC
- ✅ Detectar complejidad/TODOs
- ❌ Revisar lógica específica - usar Read normal

### project_overview
- ✅ Primera exploración de proyecto
- ✅ Cambio de contexto entre proyectos
- ✅ Entender tecnologías usadas
- ❌ Buscar archivos específicos - usar Glob

### diff_smart
- ✅ Ver qué cambió sin revisar cada línea
- ✅ Análisis de PR/commits grandes
- ✅ Estadísticas de refactors
- ❌ Revisar cambios línea por línea - usar git diff

### glob_stats
- ✅ Encontrar archivos grandes/recientes
- ✅ Análisis de distribución de código
- ✅ Listar con metadata sin leer
- ❌ Buscar por contenido - usar grep_smart

---

## Mejores Prácticas

1. **Priorizar smart-ops en exploraciones:** Primera pasada siempre con smart-ops
2. **Combinar funciones:** `project_overview` → `grep_smart count` → `read_smart summary`
3. **Usar Read/Grep normal para edición:** Smart-ops para análisis, herramientas normales para modificar
4. **Aprovechar modos específicos:** `mode: "files"` si solo necesitas nombres
5. **Límites razonables:** `limit: 10-20` en glob_stats para evitar sobrecarga

---

## MCP Fetch - Documentación Web

**Instalación:**
```bash
brew install uv  # si no tienes uvx
claude mcp add fetch -- uvx mcp-server-fetch
```

**Uso:** Cuando Claude necesita consultar documentación externa:
- Descarga la página web
- Elimina HTML basura (ads, menús, scripts, CSS)
- Convierte a Markdown limpio
- **Ahorro:** ~95% tokens vs HTML crudo

**Ejemplo:**
```
Usuario: "¿Cómo uso useEffect en React?"
Claude: [usa fetch para leer docs de React]
→ Recibe ~500 tokens de Markdown limpio
→ En lugar de ~15000 tokens de HTML con ads
```

---

## Reglas Agresivas para CLAUDE.md

Para maximizar el ahorro, añadir estas reglas al `~/.claude/CLAUDE.md`:

```markdown
## MCP Smart-Ops (OBLIGATORIO)

### Reglas de Lectura (ESTRICTAS)
1. **PROHIBIDO Read a ciegas**: NUNCA `Read` completo sin confirmar relevancia
   - Primero: `grep_smart mode: count` para ubicar
   - Luego: `read_smart mode: lines` solo rango necesario

2. **Regla del PEEK**: Antes de leer >100 líneas
   - Usar `read_smart mode: summary` (10 primeras + 10 últimas)
   - Confirmar que es el archivo correcto

3. **Planificación conservadora**: En fase de Plan
   - NO leer todos los archivos para "entender el proyecto"
   - Usar `project_overview` primero
   - Buscar evidencia específica, no barridos generales

### Prohibiciones Absolutas
❌ `Read` completo en archivos >100 líneas sin justificación
❌ `Grep` con `output_mode: "content"` (usar `grep_smart`)
❌ Múltiples `Glob + Read` (usar `project_overview`)
❌ Leer archivos "por si acaso" en fase de planificación
```

**Por qué funcionan:**
- Las reglas negativas ("NUNCA hacer X") son más efectivas que las positivas
- Fuerzan el flujo: buscar → confirmar → leer parcialmente
- Atacan específicamente el problema de "leer de más" en planificación

---

## Directorios Prohibidos

Añadir al CLAUDE.md para evitar escaneo de basura:

```markdown
## Directorios Prohibidos (NO explorar)
- `node_modules/` - dependencias npm
- `.git/` - historial git interno
- `dist/`, `build/`, `out/` - archivos compilados
- `*.min.js`, `*.bundle.js` - archivos minificados
- `.next/`, `.nuxt/`, `.cache/` - caches de frameworks
- `vendor/`, `packages/` - dependencias externas
- `coverage/` - reportes de tests
```

**Impacto:** Evita que Claude explore miles de archivos irrelevantes al hacer `project_overview` o búsquedas.

---

## Tool Search (Futuro)

**Estado:** No disponible en Claude Code CLI (v2.1.29)
- [Issue #12836](https://github.com/anthropics/claude-code/issues/12836) - 105 upvotes
- Reduciría 85% del bloat de definiciones MCP
- Betas necesarios: `advanced-tool-use-2025-11-20`, `mcp-client-2025-11-20`

**Workarounds actuales:**
- [mcp-proxy](https://github.com/TBXark/mcp-proxy)
- [mcp-gateway](https://github.com/pleaseai/mcp-gateway)

---

## Referencias

- Documentación MCP: [session-manager.md](./session-manager.md)
- Configuración: `~/.claude/CLAUDE.md` (sección MCP Smart-Ops)
- Implementación: `~/.claude/mcp-servers/session-manager/src/tools/smart-ops.ts`
