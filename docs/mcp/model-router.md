# Model Router MCP

MCP server para routing inteligente de modelos con persistencia SQLite y ML básico.

## Arquitectura

```
┌─────────────────────────────────────────┐
│ MCP: model-router                       │
│                                         │
│ - Lógica de decisión                    │
│ - Persistencia SQLite                   │
│ - ML con feedback                       │
│ - HTTP API para proxy                   │
└────────────────┬────────────────────────┘
                 │ HTTP :3457
┌────────────────▼────────────────────────┐
│ Proxy Thin                              │
│ - Solo forwarding                       │
│ - Consulta MCP para decisiones          │
└─────────────────────────────────────────┘
                 │
                 ▼
         api.anthropic.com
```

## Ubicación

```
~/.claude/mcp-servers/model-router/
├── src/
│   ├── index.ts      # MCP server + tools
│   ├── router.ts     # Lógica de decisión
│   ├── db.ts         # SQLite persistencia
│   ├── ml.ts         # ML con pesos ajustables
│   ├── http-api.ts   # API para proxy
│   └── metrics.ts    # Tracking
├── dist/             # Compilado
├── data/router.db    # SQLite DB
├── proxy-thin.js     # Proxy simplificado
├── package.json
└── tsconfig.json
```

## Tools MCP

### get_routing_stats
Ver estadísticas del router.

```json
{
  "requests": 150,
  "byTier": { "explore": 45, "code": 90, "reason": 15 },
  "tokensSaved": 125000,
  "accuracy": "85.0%",
  "recentDecisions": [...]
}
```

### set_model_preference
Forzar tier para próximos N requests.

```
tier: "explore" | "code" | "reason"
requests: número (default: 1)
```

- `explore` = haiku
- `code` = sonnet
- `reason` = opus

### clear_model_preference
Limpiar override y volver a routing automático.

### explain_last_decision
Debug de última decisión tomada.

```json
{
  "tier": "code",
  "reason": "default",
  "tokens": 5000,
  "confidence": "75%",
  "feedback": "pending"
}
```

### report_decision_feedback
Reportar si decisión fue correcta (entrena ML).

```
correct: true | false
```

### get_ml_weights
Ver pesos actuales del modelo ML.

```json
{
  "token_count_high": { "explore": 0.0, "code": 0.2, "reason": 0.8 },
  "risk_keywords": { "explore": 0.0, "code": 0.1, "reason": 0.9 },
  ...
}
```

### retrain_ml
Re-entrenar ML con feedback histórico.

## Lógica de Decisión

### Orden de Evaluación

1. **Override activo** → tier forzado
2. **Override en mensaje** (`<!-- model: opus -->`) → tier solicitado
3. **Background task** → haiku
4. **Plan mode** → opus
5. **Auto-accept mode** → opus
6. **Contexto muy largo (>100k)** → opus
7. **Contexto largo (>60k) + complejidad** → opus
8. **Contexto largo sin complejidad** → sonnet
9. **Keywords de riesgo** → opus
10. **Arquitectura + debugging** → opus
11. **Query simple** → haiku
12. **Default** → sonnet

### Keywords Detectadas

| Tipo | Keywords (ES/EN) |
|------|------------------|
| Risk | production, critical, security, migration, deploy, produccion, critico, urgente |
| Arch | refactor, redesign, restructure, architecture, refactorizar, rediseña |
| Debug | debug, root cause, investigate, trace, depurar, investigar |
| Simple | find, search, list, show, buscar, encontrar, listar, mostrar |

## ML Básico

### Features

| Feature | Descripción |
|---------|-------------|
| token_count | low/medium/high según tokens |
| risk_keywords | Presencia de keywords riesgo |
| arch_keywords | Presencia de keywords arquitectura |
| simple_keywords | Presencia de keywords simples |
| plan_mode | System prompt indica plan mode |
| background | Es tarea background/subagent |
| short_message | Mensaje <100 chars |

### Aprendizaje

- Learning rate: 0.05 (conservador)
- Ajuste por feedback positivo/negativo
- Pesos normalizados 0-1 por tier

### Uso

```
# Usuario da feedback
report_decision_feedback(correct: true)
→ Refuerza pesos de features activas para tier usado

report_decision_feedback(correct: false)
→ Penaliza tier usado, refuerza alternativas

# Re-entrenar con histórico
retrain_ml()
→ Procesa todas las decisiones con feedback
```

## Persistencia SQLite

### Tablas

```sql
-- Historial de decisiones
decisions (
  id, timestamp, tier, reason, tokens, confidence, feedback,
  token_count, message_count, last_msg_length,
  has_risk_keywords, has_arch_keywords, has_simple_keywords,
  is_plan_mode, is_background
)

-- Estadísticas acumuladas
stats (key, value)
-- keys: requests, tier_explore, tier_code, tier_reason, tokens_saved

-- Pesos ML
ml_weights (
  feature, weight_explore, weight_code, weight_reason, updated_at
)
```

## HTTP API

### POST /decide
Decisión de modelo (usado por proxy).

```json
// Request
{
  "messages": [...],
  "model": "claude-opus-4-5-20251101",
  "systemPrompt": "..."
}

// Response
{
  "tier": "code",
  "model": "claude-sonnet-4-5",
  "reason": "default",
  "confidence": 0.75,
  "decisionId": "1234-abc",
  "mlUsed": false
}
```

### POST /feedback
Feedback de decisión.

```json
{ "decisionId": "1234-abc", "correct": true }
```

### GET /stats
Estadísticas actuales.

### GET /health
Health check.

## Uso

### Iniciar Sistema

```bash
# 1. Proxy thin (en terminal separada)
node ~/.claude/mcp-servers/model-router/proxy-thin.js

# 2. Claude con proxy
ANTHROPIC_BASE_URL=http://localhost:3456 claude
```

### Verificar Funcionamiento

```bash
# Health check
curl http://127.0.0.1:3457/health

# Ver stats
curl http://127.0.0.1:3457/stats
```

### En Claude Code

```
"muéstrame las estadísticas del router"
→ get_routing_stats()

"usa opus para los próximos 5 requests"
→ set_model_preference("reason", 5)

"la última decisión fue correcta"
→ report_decision_feedback(true)

"muéstrame los pesos del ML"
→ get_ml_weights()
```

## Compilar Cambios

```bash
cd ~/.claude/mcp-servers/model-router
npm run build
# Reiniciar Claude Code para cargar cambios
```

## Beneficios vs Proxy Monolítico

| Aspecto | Antes | Después |
|---------|-------|---------|
| Código | 407 líneas JS | Modular TS |
| Estado | Ninguno | SQLite persistente |
| Métricas | No | Sí, accesibles |
| ML | No | Sí, con feedback |
| Override | Comentario HTML | Tool natural |
| Debug | Logs terminal | Tool explain |
| Mantenimiento | Difícil | Fácil (módulos) |

## Servicio macOS (launchd)

El proxy se configura como servicio para auto-iniciar al login:

```
~/.claude/mcp-servers/model-router/proxy-thin.cjs
```

### Configuración en launchd

```
~/.Library/LaunchAgents/com.claude.router.plist
```

**Características:**
- `RunAtLoad: true` → inicia al login
- `KeepAlive: true` → reinicia si crashea
- Logs en `~/.claude/mcp-servers/model-router/proxy.log`
- Escucha en puerto 3456 (proxy), 3457 (MCP API)

### Ver en vivo

```bash
tail -f ~/.claude/mcp-servers/model-router/proxy.log
```

Formato del log:
```
[HH:MM:SS] modelo-original → modelo-usado (razón)
[16:17:04] claude-opus → claude-haiku (background task)
[16:14:24] claude-haiku → claude-opus (architecture + debugging)
```

## Fixes Realizados

### Background Task Detection (2026-02-03)

**Problema:** El proxy enviaba `system` como array de objetos pero el MCP esperaba string.

**Solución:** Convertir array a string en proxy-thin.cjs:

```javascript
let systemText = '';
if (typeof body.system === 'string') {
  systemText = body.system;
} else if (Array.isArray(body.system)) {
  systemText = body.system
    .filter(block => block.type === 'text')
    .map(block => block.text)
    .join('\n');
}
```

**Resultado:** Ahora detecta correctamente:
- `run_in_background` → haiku
- `Plan mode is active` → opus
- Keywords bilingües → routing inteligente

### Timestamps en Logs

Formato actualizado de logs para debugging:
```javascript
const now = new Date();
const time = now.toTimeString().split(' ')[0];
console.log(`[${time}] ${originalModel} → ${decision.model} (${decision.reason})`);
```

## Métricas Actuales

**Estadísticas acumuladas:**
- Requests procesados: 173+
- Tokens ahorrados: 1.7M+ (~$20 USD)
- Accuracy ML: 100%
- Tier distribution: 95% code (sonnet), 4% explore (haiku), 1% reason (opus)

**Patrones detectados:**
- Background tasks → siempre haiku
- Plan mode → siempre opus
- Risk keywords → siempre opus
- Contextos >60k → opus si hay complejidad, sonnet si no

## Archivos Relacionados

- Proxy original: `examples/proxy/router.js`
- Documentación proxy: `docs/workflows/auto-router-proxy.md`
- Session manager: `docs/mcp/session-manager.md`
