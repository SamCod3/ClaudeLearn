# Gestión de Sesiones - Claude Code

## Comandos principales

| Comando | Acción | Recuperable |
|---------|--------|-------------|
| `/clear` | Borra TODO el historial | No |
| `/compact` | Comprime conversación | Parcial (resumen) |
| "Summarize from here" | Compact parcial desde punto elegido | Parcial (selectivo) |
| `Esc+Esc` o `/rewind` | Retrocede a checkpoint | Sí (selectivo) |
| `/resume` | Picker de sesiones anteriores | - |
| `claude --continue` | Retoma última sesión | - |
| `claude --resume` | Elige sesión al iniciar | - |

---

## /clear - Borrado total

### Qué hace
Borra **todo** el historial de conversación de la sesión actual.

### Qué se pierde
- Toda la conversación (prompts y respuestas)
- Contexto de archivos leídos
- Decisiones y planes discutidos

### Qué se mantiene
- Cambios en archivos (código ya escrito permanece)
- CLAUDE.md (se recarga)
- Configuración y permisos

### Cuándo usarlo
- Cambias de tarea no relacionada
- Corregiste a Claude 2+ veces sin éxito
- Contexto lleno de exploraciones fallidas

### Cuándo NO usarlo
- Estás en medio de una implementación
- Necesitas el historial para referencia

---

## Esc+Esc / /rewind - Retroceso quirúrgico

### Qué hace
Muestra checkpoints de la conversación. Puedes elegir hasta qué punto retroceder.

### Opciones al restaurar
1. **Solo conversación** - Borra mensajes pero mantiene cambios en archivos
2. **Solo código** - Revierte archivos pero mantiene conversación
3. **Ambos** - Restaura todo al estado del checkpoint

### Ejemplo práctico
```
[mensaje 1] Crear función X
[mensaje 2] Agregar tests
[mensaje 3] Pregunta sobre el tiempo  ← quieres borrar esto
[mensaje 4] Respuesta sobre el tiempo ← y esto

Esc+Esc → seleccionas checkpoint después de mensaje 2
Resultado: mensajes 3 y 4 eliminados, el resto intacto
```

### Cuándo usarlo
- Claude tomó un camino equivocado y quieres revertir
- Hiciste una pregunta irrelevante que contamina el contexto
- Quieres probar un approach diferente desde cierto punto

---

## /compact - Compresión inteligente

### Qué hace
Comprime la conversación en un resumen, liberando tokens pero manteniendo contexto esencial.

### Sintaxis
```
/compact                          # Compresión automática
/compact "enfócate en los hooks"  # Con instrucciones específicas
```

### Cuándo usarlo
- Sesión larga pero aún relevante
- Quieres liberar tokens sin perder todo
- Auto-compact se dispara cuando el contexto está casi lleno

### Tip en CLAUDE.md
```markdown
Al compactar, preservar siempre:
- Lista de archivos modificados
- Comandos de test usados
- Decisiones arquitectónicas tomadas
```

---

## "Summarize from here" - Compact parcial (v2.1.32+)

### Qué hace
Comprime solo la conversación **posterior** al mensaje seleccionado, preservando intacto todo lo anterior. Es un `/compact` quirúrgico.

### Cómo acceder
1. Navega mensajes con **flechas arriba/abajo** (message selector)
2. Selecciona el mensaje que será el punto de corte
3. Elige **"Summarize from here"** en las opciones
4. Opcionalmente escribe instrucciones de summarización (igual que `/compact`)

### Comportamiento
- Resume todo lo que está **después** del mensaje seleccionado
- Si no hay nada después: `"Nothing to summarize after the selected message."`
- Acepta instrucciones opcionales de summarización

### Comparación

| Feature | `/compact` | "Summarize from here" | `/smart-compact` (skill) |
|---------|-----------|----------------------|--------------------------|
| Scope | Toda la conversación | Desde punto seleccionado | Toda la conversación |
| Control | Instrucciones opcionales | Punto de corte + instrucciones | Automático (preserva archivos, decisiones) |
| Activación | Comando o auto-compact | Message selector (flechas) | Comando manual |
| Preserva anterior | No (todo se resume) | Sí (solo resume posterior) | Parcial (prioriza lo importante) |

### Cuándo usarlo
- La parte inicial de la conversación tiene contexto crucial
- Solo la "cola" es redundante o ruidosa
- Quieres más control que `/compact` pero menos setup que `/smart-compact`

---

## /resume y --continue - Retomar sesiones

### Desde dentro de Claude Code
```
/resume              # Abre picker de sesiones
/resume auth-feature # Busca sesión por nombre
```

### Desde terminal
```bash
claude --continue    # Retoma la más reciente en este directorio
claude --resume      # Picker interactivo
claude -r "nombre"   # Retoma sesión específica
```

### Nombrar sesiones
```
/rename mi-feature-auth
```
Facilita encontrarlas después con `/resume`.

---

## Resumen visual

```
                    ┌─────────────────────────────────────┐
                    │  Sesión con mucho contexto          │
                    │  [msg1][msg2][msg3][msg4][msg5]     │
                    └─────────────────────────────────────┘
                                    │
     ┌──────────────┬───────────────┼──────────────┐
     ▼              ▼               ▼              ▼
┌─────────┐   ┌──────────┐   ┌─────────┐   ┌───────────┐
│ /clear  │   │ Esc+Esc  │   │/compact │   │Summarize  │
│         │   │          │   │         │   │from here  │
└─────────┘   └──────────┘   └─────────┘   └───────────┘
     │              │               │              │
     ▼              ▼               ▼              ▼
┌─────────┐   ┌──────────┐   ┌─────────┐   ┌───────────┐
│ [vacío] │   │[msg1][2] │   │[resumen]│   │[1][2][res]│
│         │   │          │   │         │   │           │
└─────────┘   └──────────┘   └─────────┘   └───────────┘
Todo borrado   Quirúrgico    Comprimido    Compact parcial
No recuperable Selectivo     Todo          Desde punto elegido
```

---

## Patrón: Experimentación Segura

Usa `Esc+Esc` para explorar sin consecuencias:

### El problema
```
Tú: "¿cómo funciona X?"
Claude: [explicación 500 tokens]
Tú: "¿y si hacemos Y?"
Claude: [código 2000 tokens]
Tú: "no, mejor Z"
Claude: [más código 2000 tokens]
Tú: "vale, ahora entiendo, hazlo con W"
Claude: [finalmente lo correcto, pero 4500 tokens de ruido en contexto]
```

### La solución
```
1. Exploras, preguntas, pruebas código
2. Aprendes qué funciona y qué no
3. Esc+Esc → vuelves al inicio
4. Das instrucciones precisas con tu conocimiento nuevo
```

### Triple beneficio

| Beneficio | Descripción |
|-----------|-------------|
| **Código limpio** | Reviertes cambios fallidos |
| **Contexto limpio** | Liberas tokens de la exploración |
| **Tu conocimiento** | Aprendiste, aunque Claude "olvide" |

### Casos de uso
- Probar diferentes approaches antes de elegir uno
- Explorar una API o librería desconocida
- Hacer preguntas "tontas" sin contaminar el contexto
- Experimentar con código arriesgado

**Resumen:** Tú haces el trabajo cognitivo explorando, luego le das a Claude instrucciones directas como si ya supieras todo desde el principio.

---

## Hooks relacionados

`/clear` dispara el hook `SessionStart` con source `"clear"`:
```json
{
  "hook_event_name": "SessionStart",
  "source": "clear"
}
```

`/compact` dispara `PreCompact`:
```json
{
  "hook_event_name": "PreCompact",
  "trigger": "manual",
  "custom_instructions": "tu instrucción si la diste"
}
```
