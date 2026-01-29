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
