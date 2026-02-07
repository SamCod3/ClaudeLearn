# Hooks - Claude Code

Source: https://code.claude.com/docs/en/hooks

## Qué son los Hooks

Comandos shell que se ejecutan automáticamente en puntos específicos del ciclo de Claude Code. A diferencia de instrucciones en CLAUDE.md (advisory), los hooks son **determinísticos** - siempre se ejecutan.

## Casos de uso

- **Notificaciones** - Alertas cuando Claude espera input
- **Auto-formateo** - Ejecutar prettier/gofmt después de cada edición
- **Logging** - Registrar comandos ejecutados
- **Feedback** - Validar que el código sigue convenciones
- **Protección** - Bloquear modificaciones a archivos sensibles

---

## Eventos disponibles

| Evento | Cuándo se dispara | Uso típico |
|--------|-------------------|------------|
| `PreToolUse` | Antes de ejecutar herramienta | Validar/bloquear comandos |
| `PostToolUse` | Después de herramienta exitosa | Auto-formatear archivos |
| `PostToolUseFailure` | Después de herramienta fallida | Logging de errores |
| `PermissionRequest` | Al mostrar diálogo de permiso | Auto-aprobar/denegar |
| `UserPromptSubmit` | Usuario envía prompt | Validar/agregar contexto |
| `Stop` | Claude termina de responder | Verificar completitud |
| `SubagentStop` | Subagent termina | Verificar tarea |
| `PreCompact` | Antes de compactar contexto | Preservar info crítica |
| `Setup` | Con flags --init/--maintenance | Instalar deps, migraciones |
| `SessionStart` | Inicio/resume de sesión | Cargar contexto, env vars |
| `SessionEnd` | Fin de sesión | Cleanup, logging |
| `Notification` | Claude envía notificación | Alertas personalizadas |

---

## Configuración

Archivos de settings (orden de precedencia):
1. `~/.claude/settings.json` - Usuario (global)
2. `.claude/settings.json` - Proyecto (commit a git)
3. `.claude/settings.local.json` - Local (no commit)

### Estructura básica

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolPattern",
        "hooks": [
          {
            "type": "command",
            "command": "tu-comando-aqui"
          }
        ]
      }
    ]
  }
}
```

### Matchers
- String exacto: `Write` solo Write tool
- Regex: `Edit|Write` ambos
- `*` o `""`: todos los tools

### Variables de entorno disponibles
- `$CLAUDE_PROJECT_DIR` - Ruta absoluta al proyecto
- `$CLAUDE_ENV_FILE` - Solo en SessionStart, para persistir env vars

---

## Códigos de salida

| Exit code | Comportamiento |
|-----------|----------------|
| `0` | Éxito. stdout se muestra en modo verbose |
| `2` | Error bloqueante. stderr se muestra a Claude |
| Otro | Error no bloqueante. stderr en verbose |

---

## Async Hooks

Por defecto, los hooks son **síncronos**: Claude espera a que terminen antes de continuar. Con múltiples hooks, el tiempo se acumula y el workflow se vuelve lento.

### Habilitar async

```json
{
  "type": "command",
  "command": "python log-activity.py",
  "async": true,
  "timeout": 30
}
```

- `async: true` - El hook corre en background, Claude continúa inmediatamente
- `timeout` - Segundos máximos antes de matar el proceso (recomendado siempre)

### Cuándo usar cada modo

| Async (background) | Sync (bloquea) |
|-------------------|----------------|
| Logging, métricas | Validación en PreToolUse |
| Notificaciones (Slack, email) | Checks que deben impedir acción |
| Git commit/push | Permisos que Claude necesita saber |
| Webhooks, APIs | Cualquier resultado que afecte decisión |
| Database writes | Code quality gates |

**Regla:** Si Claude necesita el resultado para decidir qué hacer → sync. Si es side effect → async.

### Ejemplo: Logger async

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/logger.py",
            "async": true,
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

### Múltiples hooks async

Varios hooks async en el mismo evento corren **en paralelo**:

```json
{
  "hooks": [
    { "type": "command", "command": "logger.py", "async": true, "timeout": 15 },
    { "type": "command", "command": "git-commit.sh", "async": true, "timeout": 20 },
    { "type": "command", "command": "notify.py", "async": true, "timeout": 10 }
  ]
}
```

Sin async: 15 + 20 + 10 = 45s bloqueados.
Con async: ~0s bloqueados (todos corren en paralelo).

### Timeouts recomendados

| Operación | Timeout |
|-----------|---------|
| Logging local | 10-15s |
| Git local | 15-20s |
| Git con push | 30-60s |
| API/webhooks | 10-30s |
| Database | 15-30s |

---

## Ejemplos prácticos

### 1. Logging de comandos Bash

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.command' >> ~/.claude/bash-log.txt"
          }
        ]
      }
    ]
  }
}
```

### 2. Auto-formatear TypeScript con Prettier

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read f; [[ $f == *.ts ]] && npx prettier --write \"$f\"; exit 0; }"
          }
        ]
      }
    ]
  }
}
```

### 3. Notificación de escritorio (Linux)

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' 'Esperando tu input'"
          }
        ]
      }
    ]
  }
}
```

### 4. Notificación macOS

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Esperando input\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

### 5. Proteger archivos sensibles

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import json,sys; d=json.load(sys.stdin); p=d.get('tool_input',{}).get('file_path',''); sys.exit(2 if any(x in p for x in ['.env','.git/','secrets']) else 0)\""
          }
        ]
      }
    ]
  }
}
```

### 6. Ejecutar ESLint después de editar JS/TS

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/eslint-check.sh"
          }
        ]
      }
    ]
  }
}
```

Script `.claude/hooks/eslint-check.sh`:
```bash
#!/bin/bash
file_path=$(jq -r '.tool_input.file_path' < /dev/stdin)
if [[ "$file_path" =~ \.(js|ts|jsx|tsx)$ ]]; then
    npx eslint --fix "$file_path" 2>&1 || exit 2
fi
exit 0
```

### 7. Cargar contexto al iniciar sesión

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo \"Git status: $(git status -s | head -5)\""
          }
        ]
      }
    ]
  }
}
```

### 8. Persistir variables de entorno

Script para SessionStart:
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
  echo 'export DEBUG=true' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

---

## Hooks basados en Prompt (LLM)

Para decisiones que requieren contexto, usar `type: "prompt"`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Evalúa si Claude debería parar. Contexto: $ARGUMENTS. Verifica si todas las tareas están completas. Responde JSON: {\"ok\": true} para permitir parar, o {\"ok\": false, \"reason\": \"explicación\"} para continuar.",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

| Aspecto | Command hooks | Prompt hooks |
|---------|---------------|--------------|
| Ejecución | Script local | API call a Haiku |
| Lógica | Código determinístico | Evaluación contextual |
| Velocidad | Rápido | Más lento |
| Caso de uso | Reglas fijas | Decisiones complejas |

---

## Control de decisiones (JSON output)

### PreToolUse - Aprobar/Denegar herramientas

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-aprobado por política"
  }
}
```

Valores de `permissionDecision`:
- `"allow"` - Ejecutar sin preguntar
- `"deny"` - Bloquear, mostrar razón a Claude
- `"ask"` - Mostrar diálogo al usuario

### PostToolUse - Feedback a Claude

```json
{
  "decision": "block",
  "reason": "El archivo no pasa validación de estilo"
}
```

### Stop - Forzar continuar

```json
{
  "decision": "block",
  "reason": "Los tests no pasan. Debes arreglarlos antes de parar."
}
```

---

## Debugging

1. **Ver hooks registrados**: `/hooks`
2. **Logs detallados**: `claude --debug`
3. **Probar comandos manualmente** antes de registrarlos
4. **Verificar permisos**: scripts deben ser ejecutables (`chmod +x`)

---

## Seguridad

- Hooks ejecutan con tus credenciales
- Siempre revisar código antes de registrar
- Usar comillas en variables: `"$VAR"` no `$VAR`
- Validar inputs, especialmente paths
- Evitar archivos sensibles (.env, .git/, keys)

---

## Comando vs CLAUDE.md

| Aspecto | CLAUDE.md | Hooks |
|---------|-----------|-------|
| Naturaleza | Advisory (sugerencia) | Determinístico (siempre ejecuta) |
| Cumplimiento | Claude puede ignorar | Garantizado |
| Uso | Preferencias, estilo | Reglas estrictas, automatización |

---

## Tips avanzados (lecciones aprendidas)

### Exit code 2: stderr como guía para Claude

Cuando un hook devuelve `exit 2`, el stderr no solo bloquea -- **Claude lo lee y ajusta su approach**. Esto convierte el bloqueo en orientación:

```bash
# Malo: bloquea sin contexto útil
echo "Error: Validation failed" >&2
exit 2

# Bueno: guía a Claude sobre qué hacer
cat >&2 <<'MSG'
ERROR: Cannot modify production database config.
To proceed:
1. Create a migration file instead
2. Get review from @database-team
3. Use --dry-run flag first
MSG
exit 2
```

### Matcher vacío para descubrir tool names

Usar `""` como matcher captura TODOS los tools. Útil para debug:

```json
{
  "PreToolUse": [{
    "matcher": "",
    "hooks": [{"type": "command", "command": "echo \"Tool: $CLAUDE_TOOL_NAME\" >> /tmp/tools.log"}]
  }]
}
```

Después revisar `/tmp/tools.log` para ver nombres exactos (case-sensitive).

### Project settings sobreescriben global (no se mezclan)

- `~/.claude/settings.json` → global
- `.claude/settings.json` → proyecto

**Los hooks de proyecto sobreescriben completamente los globales.** No hay merge. Si defines hooks a nivel proyecto, los globales no se ejecutan.

Implicación: si necesitas hooks globales + proyecto, debes duplicar los globales en el settings del proyecto.

### Stop hook para notificaciones

Hook simple pero útil para tareas largas:

```json
{
  "Stop": [{
    "hooks": [{"type": "command", "command": "afplay /System/Library/Sounds/Glass.aiff"}]
  }]
}
```

### Tiers recomendados de implementación

| Tier | Hooks | Tiempo setup |
|------|-------|-------------|
| Essential | PostToolUse (format), Stop (notify), PreToolUse (safety) | 15 min |
| Power User | PostToolUse (auto-test), SessionStart (context), UserPromptSubmit (validation) | 1 hora |
| Pro | Audit logging en todos los eventos (SOC2/HIPAA) | 2+ horas |

### Nuestro setup actual

| Evento | Hook | Propósito |
|--------|------|-----------|
| `PostToolUse` | `check-new-dir.sh` | Detecta nuevos directorios creados |
| `UserPromptSubmit` | `token-warning.sh` | Aviso de consumo de tokens |
| `PreCompact` | `pre-compact-backup.sh` | Backup antes de compactar contexto |
| `SessionEnd` | `session-end-summary.sh` | Resumen de sesión + limpieza transcript |

**No implementados** (considerar):
- `Stop` → notificación sonora para tareas largas
- `PreToolUse` con `exit 2` → safety gates para archivos sensibles
- `SessionStart` → carga automática de contexto (git status, issues)

Fuente: [Production-Ready Claude Code Hooks Guide](https://dev.to/reza_rezvani/the-production-ready-claude-code-hooks-guide-7-hooks-that-actually-matter-o8o) (Reza Rezvani)
