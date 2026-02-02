# Personalización Visual - Claude Code CLI

Guía completa para personalizar la apariencia de Claude Code.

Sources:
- [TweakCC GitHub](https://github.com/piebald-ai/tweakcc)
- [Issue #2584 - Customizable prompt colors](https://github.com/anthropics/claude-code/issues/2584)
- [Issue #8504 - Disable user input highlighting](https://github.com/anthropics/claude-code/issues/8504)
- [CHANGELOG v2.1.23 - Spinner verbs](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

---

## Introducción

Claude Code ofrece dos niveles de personalización visual:

| Método | Tipo | Disponibilidad | Alcance |
|--------|------|----------------|---------|
| **Spinner Verbs** | Nativo | Desde v2.1.23 | Mensajes de estado |
| **TweakCC** | Comunidad | Todas las versiones | Completo (colores, temas, UI) |

**Importante:** Ninguna personalización visual consume contexto de Claude. Solo afectan el rendering en terminal.

---

## 1. Spinner Verbs (Nativo)

### ¿Qué son?

Los mensajes que aparecen mientras Claude trabaja:
- Default: "Thinking…", "Working…", "Reading files…"
- Personalizables desde v2.1.23

### Configuración

**Ubicación:** `~/.claude/settings.json`

```json
{
  "spinnerVerbs": {
    "mode": "replace",  // "append" para agregar, "replace" para reemplazar
    "verbs": [
      "Cocinando código…",
      "Preparando magia…",
      "Destilando sabiduría…",
      "Tejiendo bits…"
    ]
  }
}
```

### Ejemplos temáticos

**Jazz:**
```json
{
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": [
      "Improvising",
      "Jamming",
      "Grooving",
      "Soloing",
      "Beboppin'",
      "Scatting"
    ]
  }
}
```

**Desarrollo:**
```json
{
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": [
      "Refactoring",
      "Compiling",
      "Deploying",
      "Debugging",
      "Optimizing",
      "Transpiling"
    ]
  }
}
```

**Aplicar cambios:** Reiniciar Claude Code con `/exit` y volver a iniciar.

---

## 2. TweakCC

### ¿Qué es?

Herramienta CLI de [Piebald-AI](https://github.com/piebald-ai) que parchea el binario de Claude Code para personalización avanzada:

- ✅ Colores y temas
- ✅ Formato de mensajes del usuario
- ✅ Bordes y estilos
- ✅ Animaciones de thinking
- ✅ No consume contexto (solo visual)

### Instalación

```bash
# Ejecutar una vez
npx tweakcc

# O instalación global
npm install -g tweakcc
```

**Interfaz interactiva TUI** para configurar opciones. Los cambios se guardan en `~/.tweakcc/config.json`.

### Compatibilidad

TweakCC puede mostrar errores de parcheo con versiones muy nuevas de Claude Code:

```
patch: thinker symbol speed: failed to find match
patch: spinner no-freeze: failed to find wholeMatch
```

**Esto es normal.** Los parches fallidos son características avanzadas no críticas. La configuración básica funciona.

---

## 3. Configuración de Mensajes del Usuario

### userMessageDisplay

**Ubicación:** `~/.tweakcc/config.json`

```json
{
  "settings": {
    "userMessageDisplay": {
      "format": " > {} ",
      "styling": ["bold"],
      "foregroundColor": "default",
      "backgroundColor": "none",
      "borderStyle": "round",
      "borderColor": "rgb(148,148,148)",
      "paddingX": 0,
      "paddingY": 0,
      "fitBoxToContent": false
    }
  }
}
```

### Campos disponibles

| Campo | Valores | Descripción |
|-------|---------|-------------|
| `format` | String con `{}` | Patrón del mensaje. `{}` es reemplazado por tu texto |
| `styling` | Array | `["bold", "italic", "underline", "dim"]` |
| `foregroundColor` | Color o "default" | Color del texto |
| `backgroundColor` | Color o "none" | Color de fondo |
| `borderStyle` | String | `"round"`, `"single"`, `"double"`, `"classic"` |
| `borderColor` | RGB | `"rgb(R,G,B)"` |
| `paddingX` | Number | Padding horizontal |
| `paddingY` | Number | Padding vertical |
| `fitBoxToContent` | Boolean | Ajustar caja al contenido |

**Colores:** Formato `"rgb(255,100,50)"` o `"none"` para transparente.

### Símbolos para format

**ASCII (100% compatible):**
- `" > {} "` - Mayor que (default)
- `" → {} "` - Flecha ASCII
- `" • {} "` - Punto medio
- `" * {} "` - Asterisco
- `" $ {} "` - Signo dólar
- `" - {} "` - Guión

**Unicode (requiere buena fuente):**
- `" ● {} "` - Círculo relleno (como Claude)
- `" ▶ {} "` - Triángulo
- `" ◆ {} "` - Diamante
- `" ■ {} "` - Cuadrado
- `" ✓ {} "` - Check

**Troubleshooting símbolos:**
- Si no se ven, tu terminal/fuente no soporta Unicode
- Usa símbolos ASCII en su lugar
- Fuentes recomendadas: JetBrains Mono, Fira Code, Nerd Fonts

---

## 4. Ejemplos de Configuración

### Minimalista (sin fondo)

```json
"userMessageDisplay": {
  "format": " → {} ",
  "backgroundColor": "none",
  "borderStyle": "single",
  "borderColor": "rgb(100,100,100)"
}
```

**Resultado:**
```
┌────────────────────────────┐
│ → Tu mensaje aquí          │
└────────────────────────────┘
```

### Destacado (como Claude)

```json
"userMessageDisplay": {
  "format": " ● {} ",
  "styling": ["bold"],
  "backgroundColor": "none",
  "borderStyle": "double",
  "borderColor": "rgb(100,150,255)"
}
```

**Resultado:**
```
╔════════════════════════════╗
║ ● Tu mensaje aquí          ║
╚════════════════════════════╝
```

### Terminal clásico

```json
"userMessageDisplay": {
  "format": " $ {} ",
  "styling": ["bold"],
  "backgroundColor": "none",
  "borderStyle": "classic",
  "borderColor": "rgb(0,255,0)"
}
```

---

## 5. Otras Opciones de TweakCC

### Temas de colores

TweakCC incluye varios temas predefinidos en `config.json`:

- `"dark"` - Modo oscuro
- `"light"` - Modo claro
- `"light-ansi"` / `"dark-ansi"` - Solo colores ANSI
- `"light-daltonized"` / `"dark-daltonized"` - Amigable para daltonismo
- `"monochrome"` - Monocromo

**Editar:** Modificar `settings.themes[].colors` en el config.json.

### Thinking verbs personalizados

```json
"thinkingVerbs": {
  "format": "{}… ",
  "verbs": [
    "Thinking",
    "Processing",
    "Analyzing",
    "Computing"
  ]
}
```

### Thinking style (animación)

```json
"thinkingStyle": {
  "updateInterval": 120,
  "phases": ["·", "✢", "✳", "✶", "✻", "*"],
  "reverseMirror": true
}
```

### Input box

```json
"inputBox": {
  "removeBorder": false  // true para quitar borde del input
}
```

### Misc options

```json
"misc": {
  "showTweakccVersion": true,
  "showPatchesApplied": true,
  "expandThinkingBlocks": true,
  "hideStartupBanner": false,
  "suppressLineNumbers": true
}
```

---

## 6. Aplicar Cambios

### Después de editar config.json

1. Guardar el archivo
2. Salir de Claude Code: `/exit`
3. Reiniciar: `claude`

Los cambios se cargan al inicio.

### Volver a ejecutar TweakCC

```bash
npx tweakcc
```

Navega por el menú TUI para cambiar opciones interactivamente.

### Deshacer cambios

```bash
# Restaurar binario original
mv ~/.tweakcc/native-binary.backup /ruta/a/claude-code/binario

# O reinstalar Claude Code
```

---

## 7. Limitaciones y Consideraciones

### No soportado nativamente

Claude Code **no soporta** (cerrado como "not planned"):
- Cambiar color de fondo de mensajes del usuario sin TweakCC
- Agregar prefijos/símbolos nativamente
- Personalización de colores de prompt

**Solución:** Usar TweakCC (herramienta comunitaria).

### Compatibilidad de versiones

TweakCC puede no soportar las versiones más recientes de Claude Code inmediatamente. Los parches fallidos no afectan la funcionalidad core.

**Versión probada:** TweakCC 3.4.0 con Claude Code 2.1.29

### No consume contexto

❌ **Mito:** "TweakCC consume más tokens"
✅ **Realidad:** Es solo visual, no afecta la API de Claude

TweakCC modifica el rendering **después** de que Claude responde. No toca:
- Tokens enviados a la API
- Contexto de la conversación
- Prompt caching
- Procesamiento

---

## 8. Recursos

### Documentación oficial
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Terminal Configuration](https://code.claude.com/docs/en/terminal-config)
- [CHANGELOG v2.1.23+](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

### Comunidad
- [TweakCC GitHub](https://github.com/piebald-ai/tweakcc) - Herramienta principal
- [Spinner Themes Repo](https://github.com/MrJoeSack/spinner-themes) - Colección de temas
- [Jazz Theme Gist](https://gist.github.com/chrismo/b35434593e06fe4a2ea6eca13e4786da) - Ejemplo temático

### Issues relevantes
- [#2584 - Customizable prompt colors](https://github.com/anthropics/claude-code/issues/2584) (cerrado)
- [#8504 - Disable user input highlighting](https://github.com/anthropics/claude-code/issues/8504) (abierto)

---

## Resumen

| Personalización | Método | Archivo | Reinicio requerido |
|-----------------|--------|---------|-------------------|
| Spinner verbs | Nativo | `~/.claude/settings.json` | Sí |
| Colores/temas | TweakCC | `~/.tweakcc/config.json` | Sí |
| Mensajes usuario | TweakCC | `~/.tweakcc/config.json` | Sí |
| Thinking style | TweakCC | `~/.tweakcc/config.json` | Sí |

**Flujo recomendado:**
1. Empezar con spinner verbs (nativo, simple)
2. Si necesitas más, instalar TweakCC
3. Configurar userMessageDisplay según tu gusto
4. Explorar temas y opciones avanzadas
