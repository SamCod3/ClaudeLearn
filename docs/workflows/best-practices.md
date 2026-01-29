# Best Practices - Claude Code

Source: https://code.claude.com/docs/en/best-practices

## Principio Fundamental

> La ventana de contexto se llena rápido y el rendimiento degrada cuando se llena.

Casi todas las mejores prácticas derivan de este constraint.

---

## 1. Dale a Claude forma de verificar su trabajo

**El consejo más importante.** Claude funciona dramáticamente mejor cuando puede verificarse a sí mismo.

| Estrategia | Mal ejemplo | Buen ejemplo |
|------------|-------------|--------------|
| Criterios de verificación | "implementa validación de email" | "escribe validateEmail. casos de test: user@example.com true, invalid false. ejecuta los tests después" |
| Verificar UI visualmente | "mejora el dashboard" | "[pegar screenshot] implementa este diseño. toma screenshot del resultado y compara" |
| Causa raíz | "el build falla" | "el build falla con este error: [error]. arréglalo y verifica que el build pasa" |

---

## 2. Explora primero, planifica después, codifica al final

Usa **Plan Mode** para separar exploración de ejecución:

```
1. EXPLORE (Plan Mode)
   "lee /src/auth y entiende cómo manejamos sesiones"

2. PLAN (Plan Mode)
   "quiero agregar OAuth. ¿qué archivos cambiar? crea un plan"
   Ctrl+G para editar el plan en tu editor

3. IMPLEMENT (Normal Mode)
   "implementa el flujo OAuth del plan. escribe tests, ejecútalos"

4. COMMIT
   "commit con mensaje descriptivo y abre PR"
```

**Cuándo saltarse el plan:** Si puedes describir el diff en una oración (typo, agregar log, renombrar variable).

---

## 3. Contexto específico en prompts

| Estrategia | Mal | Bien |
|------------|-----|------|
| Acotar tarea | "agrega tests para foo.py" | "test para foo.py cubriendo el edge case de usuario logged out. sin mocks" |
| Apuntar a fuentes | "¿por qué ExecutionFactory tiene API rara?" | "revisa el git history de ExecutionFactory y resume cómo llegó su API a ser así" |
| Patrones existentes | "agrega widget calendario" | "mira cómo están implementados los widgets en home page. HotDogWidget.php es buen ejemplo. sigue el patrón" |

### Contenido rico
- **`@archivo`** - referencia archivos directamente
- **Pegar imágenes** - drag & drop o copy/paste
- **URLs** - documentación y APIs
- **Pipe data** - `cat error.log | claude`

---

## 4. Configura tu entorno

### CLAUDE.md efectivo

Ejecuta `/init` para generar uno inicial, luego refina.

**Incluir:**
- Comandos Bash que Claude no puede adivinar
- Reglas de estilo que difieren de defaults
- Instrucciones de testing
- Convenciones del repo (branches, PRs)
- Decisiones arquitectónicas específicas
- Gotchas no obvios

**NO incluir:**
- Lo que Claude puede inferir del código
- Convenciones estándar del lenguaje
- Documentación detallada (mejor linkear)
- Info que cambia frecuentemente
- Descripciones archivo por archivo

> Si Claude sigue ignorando una regla, el archivo probablemente es muy largo.

### Permisos
- `/permissions` - allowlist comandos seguros
- `/sandbox` - aislamiento a nivel OS
- `--dangerously-skip-permissions` - solo en sandbox sin internet

### CLI tools
Instala `gh`, `aws`, `gcloud`, etc. Son la forma más eficiente de interactuar con servicios externos.

### Hooks
Para acciones que DEBEN pasar siempre sin excepción. Son determinísticos (vs CLAUDE.md que es advisory).

```
"Escribe un hook que ejecute eslint después de cada edición"
"Escribe un hook que bloquee writes a la carpeta migrations"
```

### Skills
`SKILL.md` en `.claude/skills/` para conocimiento de dominio y workflows reutilizables.

### Subagents personalizados
`.claude/agents/` para asistentes especializados que corren en su propio contexto.

---

## 5. Comunicación efectiva

### Preguntas sobre codebase
Pregunta como a un ingeniero senior:
- ¿Cómo funciona el logging?
- ¿Cómo hago un nuevo endpoint?
- ¿Qué hace `async move { ... }` en línea 134 de foo.rs?

### Deja que Claude te entreviste
Para features grandes:
```
Quiero construir [descripción breve]. Entrevístame en detalle usando AskUserQuestion.

Pregunta sobre implementación técnica, UX, edge cases, tradeoffs.
Sigue entrevistando hasta cubrir todo, luego escribe spec completa en SPEC.md.
```

---

## 6. Gestiona tu sesión

### Corrige temprano y frecuentemente
- **`Esc`** - detener Claude mid-action
- **`Esc + Esc`** o **`/rewind`** - restaurar estado anterior
- **`"Undo that"`** - revertir cambios
- **`/clear`** - reset entre tareas no relacionadas

> Si corregiste a Claude más de 2 veces en el mismo issue, `/clear` y empieza fresh con mejor prompt.

### Gestiona contexto agresivamente
- `/clear` frecuentemente entre tareas
- `/compact <instrucciones>` para control manual
- En CLAUDE.md: `"Al compactar, preserva siempre la lista completa de archivos modificados"`

### Usa subagents para investigación
```
Usa subagents para investigar cómo nuestro sistema de auth
maneja token refresh, y si tenemos utilidades OAuth existentes.
```

El subagent explora sin llenar tu contexto principal.

### Checkpoints
Cada acción crea un checkpoint. `Esc Esc` o `/rewind` para restaurar.

### Resumir conversaciones
```bash
claude --continue    # Más reciente
claude --resume      # Elegir de recientes
```

`/rename` para dar nombres descriptivos a sesiones.

---

## 7. Automatiza y escala

### Headless mode
```bash
claude -p "Explica qué hace este proyecto"
claude -p "Lista endpoints" --output-format json
claude -p "Analiza log" --output-format stream-json
```

### Múltiples sesiones paralelas
- **Claude Desktop** - sesiones locales con worktrees aislados
- **Claude Code web** - VMs aisladas en cloud

**Patrón Writer/Reviewer:**
- Session A: "Implementa rate limiter"
- Session B: "Revisa el rate limiter en @src/middleware/rateLimiter.ts"
- Session A: "Aquí está el feedback: [output B]. Arregla estos issues"

### Fan-out
```bash
for file in $(cat files.txt); do
  claude -p "Migra $file de React a Vue. Retorna OK o FAIL." \
    --allowedTools "Edit,Bash(git commit *)"
done
```

---

## 8. Patrones de fallo comunes

| Patrón | Problema | Solución |
|--------|----------|----------|
| Kitchen sink session | Tareas no relacionadas mezcladas | `/clear` entre tareas |
| Corregir una y otra vez | Contexto lleno de intentos fallidos | Después de 2 correcciones, `/clear` y mejor prompt |
| CLAUDE.md sobre-especificado | Claude ignora reglas importantes | Podar sin piedad |
| Trust-then-verify gap | Implementación plausible sin edge cases | Siempre proveer verificación |
| Exploración infinita | Claude lee cientos de archivos | Acotar investigaciones o usar subagents |

---

## Desarrolla tu intuición

Los patrones son puntos de partida. A veces:
- Deja que el contexto se acumule (problema complejo, historial valioso)
- Salta el plan (tarea exploratoria)
- Prompt vago (ver cómo Claude interpreta el problema)

**Observa qué funciona.** Cuando Claude produce buen output, nota: estructura del prompt, contexto provisto, modo usado.
