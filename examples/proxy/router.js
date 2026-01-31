#!/usr/bin/env node
/**
 * Claude Auto-Router Proxy
 * Detecta familia del modelo y deriva haiku/sonnet/opus automáticamente
 *
 * Uso: node router.js
 * Luego: ANTHROPIC_BASE_URL=http://localhost:3456 claude
 */

const http = require('http');
const https = require('https');

// Configuración
const CONFIG = {
  port: 3456,
  anthropicUrl: 'api.anthropic.com',

  // Modelos por tier (se detectan del primer request)
  models: {
    low: null,     // haiku
    medium: null,  // sonnet (detectado del request)
    high: null     // opus
  },

  // Umbrales
  longContextThreshold: 60000,
  shortPromptThreshold: 50,

  // Keywords
  keywords: {
    risk: /\b(production|critical|security|migration|deploy|produccion|critico|urgente|seguridad|migracion|desplegar|peligroso)\b/i,
    arch: /\b(refactor|redesign|restructure|architecture|refactorizar|rediseña|reestructurar|desacoplar|modularizar)\b/i,
    debug: /\b(debug|root.?cause|investigate|trace|depurar|investigar|por.?que.?(no.?)?funciona|causa.?raiz|analizar)\b/i,
    simple: /\b(find|search|list|where.?is|what.?is|show|buscar|busca|encontrar|listar|mostrar|donde.?esta|que.?es|dame)\b/i
  }
};

// Estado
let modelsDetected = false;

// Detectar familia del modelo y derivar otros (usando aliases sin fecha)
function detectModelFamily(modelId) {
  if (modelsDetected) return;

  // Patrones de modelo: claude-{type}-{major}-{minor}[-{date}] o claude-{major}-{minor}-{type}[-{date}]
  // Ejemplos: claude-opus-4-5-20251101, claude-sonnet-4-5, claude-3-5-sonnet-20241022

  let family = null;

  // Patrón nuevo: claude-{type}-{major}-{minor}[-{date}]
  const newPattern = /claude-(sonnet|opus|haiku)-(\d+)-(\d+)/;
  // Patrón viejo: claude-{major}-{minor}-{type}[-{date}]
  const oldPattern = /claude-(\d+)-(\d+)-(sonnet|opus|haiku)/;

  let match = modelId.match(newPattern);
  if (match) {
    const [, type, major, minor] = match;
    family = `${major}-${minor}`;

    // Usar aliases sin fecha (Anthropic los resuelve a la versión más reciente)
    CONFIG.models.low = `claude-haiku-${family}`;
    CONFIG.models.medium = `claude-sonnet-${family}`;
    CONFIG.models.high = `claude-opus-${family}`;
  } else {
    match = modelId.match(oldPattern);
    if (match) {
      const [, major, minor, type] = match;
      family = `${major}-${minor}`;

      // Patrón viejo con aliases
      CONFIG.models.low = `claude-${family}-haiku`;
      CONFIG.models.medium = `claude-${family}-sonnet`;
      CONFIG.models.high = `claude-${family}-opus`;
    }
  }

  if (family) {
    console.log(`[Router] Familia detectada: ${family}`);
    console.log(`[Router] Modelos (aliases):`);
    console.log(`  LOW    → ${CONFIG.models.low}`);
    console.log(`  MEDIUM → ${CONFIG.models.medium}`);
    console.log(`  HIGH   → ${CONFIG.models.high}`);
    modelsDetected = true;
  } else {
    // Fallback: usar el modelo original para todo
    console.log(`[Router] No se pudo detectar familia de: ${modelId}`);
    console.log(`[Router] Usando modelo original para todos los tiers`);
    CONFIG.models.low = modelId;
    CONFIG.models.medium = modelId;
    CONFIG.models.high = modelId;
    modelsDetected = true;
  }
}

// Estimar tokens
function estimateTokens(messages) {
  if (!messages) return 0;
  const text = JSON.stringify(messages);
  return Math.ceil(text.length / 4);
}

// Extraer último mensaje del usuario
function getLastUserMessage(messages) {
  if (!Array.isArray(messages)) return '';
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === 'user') {
      const content = messages[i].content;
      if (typeof content === 'string') return content;
      if (Array.isArray(content)) {
        return content
          .filter(c => c.type === 'text')
          .map(c => c.text)
          .join(' ');
      }
    }
  }
  return '';
}

// Detectar tarea background
function isBackgroundTask(body) {
  const systemPrompt = body.system || '';
  if (typeof systemPrompt === 'string') {
    if (systemPrompt.includes('subagent') || systemPrompt.includes('background')) {
      return true;
    }
  }
  if (body.model && body.model.includes('haiku')) {
    return true;
  }
  return false;
}

// Extraer texto del system prompt (puede ser string o array)
function getSystemText(body) {
  const system = body.system;
  if (typeof system === 'string') {
    return system;
  }
  if (Array.isArray(system)) {
    return system
      .filter(block => block.type === 'text' && block.text)
      .map(block => block.text)
      .join(' ');
  }
  return '';
}

// Detectar Plan Mode (requiere análisis profundo y diseño)
function isPlanMode(body) {
  const systemText = getSystemText(body);
  return /plan\s*mode\s*(is\s*)?(still\s*)?active/i.test(systemText);
}

// Detectar Auto-Accept Mode (sin supervisión humana, requiere precisión)
function isAutoAcceptMode(body) {
  const systemText = getSystemText(body);
  // Posibles indicadores de auto-accept
  return /auto[_-]?accept/i.test(systemText) ||
         /accept\s*edits?\s*on/i.test(systemText) ||
         /without\s*(asking|permission|confirmation)/i.test(systemText);
}

// Decidir modelo según contexto
function selectModel(body) {
  const messages = body.messages || [];
  const tokens = estimateTokens(messages);
  const lastMessage = getLastUserMessage(messages);
  const originalModel = body.model || '';

  // Detectar familia en primer request
  if (!modelsDetected && originalModel) {
    detectModelFamily(originalModel);
  }

  // Si no hay modelos detectados, usar original
  if (!CONFIG.models.medium) {
    return { model: originalModel, tier: 'medium', reason: 'no models detected' };
  }

  let tier = 'medium';
  let reason = 'default';

  // Plan Mode: análisis profundo, diseño arquitectónico
  if (isPlanMode(body)) {
    return { model: CONFIG.models.high, tier: 'high', reason: 'plan mode' };
  }

  // Auto-Accept: sin supervisión humana, requiere máxima precisión
  if (isAutoAcceptMode(body)) {
    return { model: CONFIG.models.high, tier: 'high', reason: 'auto-accept mode' };
  }

  // Background tasks: operaciones internas de bajo costo
  if (isBackgroundTask(body)) {
    return { model: CONFIG.models.low, tier: 'low', reason: 'background task' };
  }

  if (tokens > CONFIG.longContextThreshold) {
    return { model: CONFIG.models.high, tier: 'high', reason: `long context (${tokens} tokens)` };
  }

  if (CONFIG.keywords.risk.test(lastMessage)) {
    tier = 'high';
    reason = 'risk keywords detected';
  } else if (CONFIG.keywords.arch.test(lastMessage) && CONFIG.keywords.debug.test(lastMessage)) {
    tier = 'high';
    reason = 'architecture + debugging';
  } else if (CONFIG.keywords.simple.test(lastMessage) &&
             lastMessage.length < CONFIG.shortPromptThreshold &&
             !CONFIG.keywords.arch.test(lastMessage) &&
             !CONFIG.keywords.debug.test(lastMessage)) {
    tier = 'low';
    reason = 'simple query';
  }

  return { model: CONFIG.models[tier], tier, reason };
}

// Manejar request
function handleRequest(req, res) {
  // Solo procesar POST a /v1/messages
  if (req.method !== 'POST' || !req.url.startsWith('/v1/messages')) {
    proxyRequest(req, res, null);
    return;
  }

  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', () => {
    try {
      const parsed = JSON.parse(body);
      const originalModel = parsed.model;
      const { model, tier, reason } = selectModel(parsed);

      parsed.model = model;

      if (model !== originalModel) {
        console.log(`[Router] ${originalModel} → ${model} (${reason})`);
      }

      proxyRequest(req, res, JSON.stringify(parsed));
    } catch (e) {
      console.error('[Router] Parse error:', e.message);
      proxyRequest(req, res, body);
    }
  });
}

// Proxy al API real
function proxyRequest(req, res, modifiedBody) {
  const options = {
    hostname: CONFIG.anthropicUrl,
    port: 443,
    path: req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: CONFIG.anthropicUrl
    }
  };

  if (modifiedBody) {
    options.headers['content-length'] = Buffer.byteLength(modifiedBody);
  }

  const proxyReq = https.request(options, proxyRes => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', err => {
    console.error('[Router] Proxy error:', err.message);
    res.writeHead(502);
    res.end(JSON.stringify({ error: err.message }));
  });

  if (modifiedBody) {
    proxyReq.write(modifiedBody);
    proxyReq.end();
  } else {
    req.pipe(proxyReq);
  }
}

// Iniciar servidor
const server = http.createServer(handleRequest);

server.listen(CONFIG.port, '127.0.0.1', () => {
  console.log(`
╔════════════════════════════════════════════════════════════╗
║  Claude Auto-Router Proxy                                  ║
╠════════════════════════════════════════════════════════════╣
║  Listening: http://127.0.0.1:${CONFIG.port}                       ║
║                                                            ║
║  Detecta familia del modelo automáticamente                ║
║  Deriva haiku/sonnet/opus de la misma versión              ║
║                                                            ║
║  Para usar:                                                ║
║    ANTHROPIC_BASE_URL=http://localhost:${CONFIG.port} claude      ║
╚════════════════════════════════════════════════════════════╝
`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n[Router] Shutting down...');
  server.close(() => process.exit(0));
});
