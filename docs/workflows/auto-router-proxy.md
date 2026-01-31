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

## Modelos configurados

| Tier | Modelo | Cuándo |
|------|--------|--------|
| LOW | claude-haiku-4-5-20251001 | Queries simples, background tasks |
| MEDIUM | claude-sonnet-4-5-20251101 | Default |
| HIGH | claude-opus-4-5-20251101 | Riesgo, arquitectura compleja, long context |

## Reglas de routing

```
1. Background/subagent task           → haiku
2. >60K tokens                        → opus
3. Keywords riesgo (produccion, etc)  → opus
4. Arquitectura + debugging           → opus
5. Query simple (<50 chars)           → haiku
6. Default                            → sonnet
```

## Archivos

| Archivo | Ubicación |
|---------|-----------|
| Proxy | `~/.claude/proxy/router.js` |
| Script inicio | `~/.claude/proxy/start-claude.sh` |
| Servicio launchd | `~/Library/LaunchAgents/com.claude.router.plist` |
| Logs | `~/.claude/proxy/router.log` |

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
[Router] claude-sonnet-4-5 → claude-haiku-4-5 (simple query)
[Router] claude-sonnet-4-5 → claude-opus-4-5 (risk keywords detected)
[Router] claude-sonnet-4-5 → claude-opus-4-5 (long context 65000 tokens)
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
// Cambiar modelos
models: {
  low: 'claude-haiku-4-5-20251001',
  medium: 'claude-sonnet-4-5-20251101',
  high: 'claude-opus-4-5-20251101'
},

// Ajustar umbral de tokens para opus
longContextThreshold: 60000,

// Añadir keywords
keywords: {
  risk: /\b(production|critical|security|...)\b/i,
  // ...
}
```

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
```

### Ver errores
```bash
cat ~/.claude/proxy/router.log
```
