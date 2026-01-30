# LSP (Language Server Protocol) - Claude Code

Source: Claude Code v2.0.74+ / Artículo "How I'm Using Claude Code LSP"

---

## Qué es LSP

Language Server Protocol es un protocolo creado por Microsoft que estandariza la comunicación entre editores de código y "language servers" - programas que entienden la semántica de un lenguaje.

**Sin LSP:** Claude Code hace "grep inteligente" - busca patrones de texto en archivos.

**Con LSP:** Claude Code consulta el language server directamente, obteniendo la misma inteligencia que tu IDE.

---

## Operaciones disponibles

| Operación | Equivalente en IDE | Uso |
|-----------|-------------------|-----|
| `goToDefinition` | Ctrl+Click | Saltar a donde se define una función/variable |
| `findReferences` | Find All References | Encontrar todos los usos en el codebase |
| `hover` | Hover tooltip | Ver firma, parámetros, documentación |
| `documentSymbol` | Outline view | Listar todos los símbolos de un archivo |
| `workspaceSymbol` | Go to Symbol | Buscar símbolos en todo el proyecto |
| `diagnostics` | Red squiggles | Errores y warnings en tiempo real |

---

## Configuración

### Paso 1: Habilitar LSP Tools

Agregar a tu shell profile (`.zshrc`, `.bashrc`):

```bash
export ENABLE_LSP_TOOLS=1
```

Reiniciar terminal o `source ~/.zshrc`.

### Paso 2: Instalar plugin de lenguaje

```
/plugin
→ Seleccionar plugin para tu lenguaje
→ "Install for me only" (user scope)
```

### Paso 3: Instalar el language server

El plugin necesita el binario del language server instalado en tu sistema:

| Lenguaje | Plugin | Instalar binario |
|----------|--------|------------------|
| Python | `pyright-lsp` | `pip install pyright` |
| TypeScript/JS | `vtsls` | `npm install -g @vtsls/language-server typescript` |
| Go | `gopls` | `go install golang.org/x/tools/gopls@latest` |
| Rust | `rust-analyzer` | `rustup component add rust-analyzer` |

### Paso 4: Reiniciar Claude Code

```bash
claude
```

### Paso 5: Verificar

```
/plugin
→ Pestaña "Installed"
→ Debería mostrar tu plugin LSP
```

Probar con:
```
Find references to myFunction using LSP
```

---

## Lenguajes soportados

Plugins disponibles out-of-the-box:

- Python (pyright)
- TypeScript/JavaScript (vtsls, typescript-lsp)
- Go (gopls)
- Rust (rust-analyzer)
- C/C++ (clangd)
- Java (jdtls)
- PHP (phpactor, intelephense)
- Ruby (solargraph)
- Kotlin (kotlin-language-server)
- Swift (sourcekit-lsp)

---

## Uso práctico

### Encontrar definición

```
Where is the processRequest function defined? Use LSP.
```

Claude salta directamente al archivo y línea exacta.

### Encontrar todas las referencias

```
Find all references to displayError using LSP
```

Retorna cada lugar donde se usa la función - útil para refactoring.

### Ver parámetros de función

```
What parameters does displayBooks accept? Use LSP.
```

Muestra firma completa con tipos y documentación.

### Listar símbolos de archivo

```
Show me all symbols in backend/index.js using LSP
```

### Buscar símbolos en proyecto

```
Find all methods that contain innerHTML
```

---

## Cuándo usar LSP vs búsqueda normal

| Usar LSP | Usar Grep/Glob normal |
|----------|----------------------|
| Codebase grande (100+ archivos) | Scripts pequeños |
| Debugging cross-file | Buscar strings literales |
| Necesitas firmas exactas | Búsquedas rápidas |
| Refactoring (qué se rompe?) | Proyectos sin language server |
| Lenguajes con tipos | |

---

## Tips

1. **Verificar setup**: Después de instalar, probar con "find references to X using LSP"

2. **Ser explícito**: Si Claude no usa LSP, agregar "use LSP" al prompt

3. **Revisar PATH**: Si dice "No LSP server available", verificar que el binario está en PATH:
   ```bash
   which pyright  # o tu language server
   ```

4. **Reiniciar después de cambios**: Los servers se cargan al inicio

5. **No todo necesita LSP**: Para búsquedas simples de texto, grep es más rápido

---

## Limitaciones actuales

- **Sin indicador visual**: No hay status bar mostrando que LSP está activo
- **Feature nueva**: Puede haber bugs, revisar GitHub issues
- **Binario separado**: El plugin no instala el language server, solo lo conecta
- **Overhead**: Para proyectos pequeños, el setup no vale la pena

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| "No LSP server available" | Instalar binario y verificar PATH |
| Plugin no aparece en /plugin | Reiniciar Claude Code |
| LSP no se usa automáticamente | Agregar "use LSP" al prompt |
| Errores al iniciar server | Verificar versión del language server |
