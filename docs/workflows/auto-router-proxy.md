# Auto-Router Proxy

Proxy local que cambia automáticamente entre haiku/sonnet/opus según el contexto de cada request.

## Problema

El hook `model-router.sh` solo **recomienda** modelos pero no puede cambiarlos automáticamente. Claude Code no permite cambiar el modelo programáticamente durante una sesión.

## Solución

Un proxy HTTP que intercepta las requests de Claude Code, analiza el contexto, y modifica el campo `model` antes de reenviar a Anthropic.

```
Claude Code → localhost:3456 (proxy) → api.anthropic.com
                    ↓
            Analiza contexto
            Cambia model en request
```

## Detección automática de modelos

El proxy detecta la familia del modelo del primer request y deriva los otros **usando aliases**:

```
Request: claude-opus-4-5-20251101
         ↓
Familia: 4-5
         ↓
LOW    → claude-haiku-4-5    (alias)
MEDIUM → claude-sonnet-4-5   (alias)
HIGH   → claude-opus-4-5     (alias)
```

**Por qué aliases:** Las fechas de snapshot son diferentes por modelo:
- `claude-opus-4-5-20251101` (Opus 4.5)
- `claude-sonnet-4-5-20250929` (Sonnet 4.5) ← fecha diferente

Si deriváramos con fechas específicas (ej: `claude-sonnet-4-5-20251101`), obtendríamos **404 error** porque ese snapshot no existe. Los aliases permiten que Anthropic resuelva a la versión más reciente de cada tier.

**Ventaja:** Cuando Anthropic lance nuevas versiones, los aliases apuntan automáticamente a los snapshots más recientes sin necesidad de actualizar el proxy.

| Tier | Modelo | Cuándo |
|------|--------|--------|
| LOW | haiku (auto) | Queries simples, background tasks |
| MEDIUM | sonnet (auto) | Default |
| HIGH | opus (auto) | Riesgo, arquitectura compleja, long context |

## Reglas de routing

```
1. Plan Mode activo                   → opus  (diseño arquitectónico)
2. Auto-Accept Mode activo            → opus  (sin supervisión, requiere precisión)
3. Background/subagent task           → haiku (operaciones internas)
4. >60K tokens                        → opus  (contexto largo)
5. Keywords riesgo (produccion, etc)  → opus
6. Arquitectura + debugging           → opus
7. Query simple (<50 chars)           → haiku
8. Default                            → sonnet
```

## Detección de modos

El proxy detecta automáticamente el modo de Claude Code:

| Modo | Atajo | Modelo | Razón |
|------|-------|--------|-------|
| **Plan Mode** | `Shift+Tab` x2 | Opus | Análisis profundo, diseño |
| **Auto-Accept** | `Shift+Tab` | Opus | Sin revisión humana |
| **Normal** | - | Sonnet | Balance costo/calidad |

### Cómo funciona

El proxy analiza el **system prompt** que Claude Code envía:

```javascript
// Plan Mode
/plan\s*mode\s*(is\s*)?(still\s*)?active/i

// Auto-Accept Mode
/auto[_-]?accept/i || /accept\s*edits?\s*on/i
```

### Ejemplo en logs

```
[Router] claude-opus-4-5 → claude-opus-4-5 (plan mode)
[Router] claude-opus-4-5 → claude-opus-4-5 (auto-accept mode)
[Router] claude-opus-4-5 → claude-sonnet-4-5 (default)
```

## Archivos

| Archivo | Ubicación |
|---------|-----------|
| Proxy (producción) | `~/.claude/proxy/router.js` |
| Proxy (referencia) | `examples/proxy/router.js` |
| Script inicio | `~/.claude/proxy/start-claude.sh` |
| Servicio launchd | `~/Library/LaunchAgents/com.claude.router.plist` |
| Logs | `~/.claude/proxy/router.log` |

**Nota:** La versión de `examples/proxy/` es para versionado en git. La versión activa es `~/.claude/proxy/`.

## Instalación

### 1. El proxy ya está en `~/.claude/proxy/router.js`

### 2. Servicio launchd (auto-inicio)

```bash
# Cargar servicio (arranca automáticamente en login)
launchctl load ~/Library/LaunchAgents/com.claude.router.plist

# Verificar
launchctl list | grep claude.router
```

### 3. Alias en ~/.zshrc

```bash
# Claude Code con auto-router
alias claude="ANTHROPIC_BASE_URL=http://localhost:3456 command claude"
```

## Uso

```bash
# Simplemente usar claude normalmente
claude

# El proxy detecta y cambia modelos automáticamente
# Ver logs en tiempo real:
tail -f ~/.claude/proxy/router.log
```

## Logs de ejemplo

```
[Router] Familia detectada: 4-5
[Router] Modelos (aliases):
  LOW    → claude-haiku-4-5
  MEDIUM → claude-sonnet-4-5
  HIGH   → claude-opus-4-5
[Router] claude-opus-4-5-20251101 → claude-haiku-4-5 (simple query)
[Router] claude-opus-4-5-20251101 → claude-sonnet-4-5 (default)
[Router] claude-opus-4-5-20251101 → claude-opus-4-5 (risk keywords detected)
[Router] claude-haiku-4-5-20251001 → claude-haiku-4-5 (background task)
```

## Verificación de funcionamiento

### Método 1: Comando /usage

Dentro de Claude Code:
```
/usage
```

Verifica que **Sonnet** tenga uso (no solo Opus). Si antes estaba en 0% y ahora tiene actividad, el proxy está funcionando.

### Método 2: Logs en tiempo real

Terminal 1 (monitorizar):
```bash
tail -f ~/.claude/proxy/router.log
```

Terminal 2 (usar Claude):
```bash
claude
# Haz preguntas normales → verás routing a sonnet
# Menciona "production" o "security" → verás routing a opus
```

### Método 3: Verificar proceso

```bash
# Proxy escuchando en puerto 3456
lsof -i:3456

# Debe mostrar:
# node ... router.js ... TCP localhost:vat (LISTEN)
```

## Comandos de gestión

```bash
# Estado del servicio
launchctl list | grep claude.router

# Ver logs
tail -f ~/.claude/proxy/router.log

# Reiniciar proxy
launchctl stop com.claude.router && launchctl start com.claude.router

# Desactivar auto-inicio
launchctl unload ~/Library/LaunchAgents/com.claude.router.plist

# Usar claude SIN proxy (modelo fijo)
command claude
```

## Personalización

Editar `~/.claude/proxy/router.js`:

```javascript
// Ajustar umbral de tokens para opus
longContextThreshold: 60000,

// Ajustar umbral de chars para queries simples
shortPromptThreshold: 50,

// Añadir keywords
keywords: {
  risk: /\b(production|critical|security|...)\b/i,
  simple: /\b(find|search|list|...)\b/i,
  // ...
}
```

**Nota:** Los modelos se detectan automáticamente de la familia del primer request. No necesitas actualizarlos manualmente.

## Comparación con alternativas

| Aspecto | model-router.sh (hook) | Este proxy | claude-code-router |
|---------|------------------------|------------|-------------------|
| Tipo | Recomendación | Cambio real | Cambio real |
| Proveedores | Solo Anthropic | Solo Anthropic | Multi-provider |
| Complejidad | Mínima | Baja | Alta |
| Instalación | Solo hook | Node.js + launchd | npm global |
| Multi-provider | No | No | Sí |

## Inspiración

- [claude-code-router](https://github.com/musistudio/claude-code-router) - Proxy completo multi-provider
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) - Sistema de routing por keywords

## Troubleshooting

### Error 404: model not found

**Síntoma:**
```
API Error: 404 {"error":{"message":"model: claude-sonnet-4-5-20251101"}}
```

**Causa:** El proxy estaba derivando modelos con fechas específicas que no existen. Anthropic usa fechas diferentes por tier (Opus: `20251101`, Sonnet: `20250929`).

**Solución:** Actualizar `~/.claude/proxy/router.js` para usar aliases sin fecha:

```javascript
// ❌ Antes (incorrecto)
CONFIG.models.medium = `claude-sonnet-${family}-${date}`;

// ✅ Ahora (correcto)
CONFIG.models.medium = `claude-sonnet-${family}`;  // sin fecha
```

Luego reiniciar el proxy:
```bash
pkill -f router.js
launchctl start com.claude.router
```

### Proxy no arranca
```bash
# Verificar node
which node

# Probar manualmente
node ~/.claude/proxy/router.js
```

### Claude no usa el proxy
```bash
# Verificar alias
alias claude

# Verificar puerto
lsof -i :3456

# Debe mostrar ANTHROPIC_BASE_URL
echo $ANTHROPIC_BASE_URL  # cuando alias está activo
```

### Ver errores
```bash
# Ver todo el log
cat ~/.claude/proxy/router.log

# Ver solo errores
grep -i error ~/.claude/proxy/router.log

# Seguir en tiempo real
tail -f ~/.claude/proxy/router.log
```
