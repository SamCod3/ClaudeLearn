# Session Health Check

Verifica el estado de las sesiones del proyecto actual y muestra warnings preventivos antes de que ocurra lentitud en `--resume`.

**✨ USO DUAL:** Funciona desde Claude (skill) o terminal (comando standalone)

## Qué hace

- Analiza número y tamaño de sesiones del proyecto actual
- Muestra health score visual (🟢🟡🔴) según métricas
- Explica por qué importa cada métrica (contexto educativo)
- Sugiere acciones según el estado de salud
- Ofrece limpieza manual si es necesario

## Cuándo usarlo

- Si notas que `--resume` tarda más de lo normal (>3 segundos)
- Periódicamente (cada semana) para monitoreo preventivo
- Después de sesiones muy largas (>100 mensajes)
- Para entender qué hace `cleanupPeriodDays` en tu proyecto

## Health Score

- 🟢 **VERDE (Saludable):** <15 sesiones, <5MB total, todas <2MB
- 🟡 **AMARILLO (Atención):** 15-25 sesiones, 5-10MB total, o alguna >2MB
- 🔴 **ROJO (Peligro):** >25 sesiones, >10MB total, o alguna >5MB

## Uso

### Desde Claude (modo skill)

```bash
/session-health           # Análisis completo
/session-health --cleanup # Limpieza interactiva
/session-health --quiet   # Solo health score
```

### Desde terminal (modo standalone)

```bash
claude-maintenance           # Análisis completo
claude-maintenance --cleanup # Limpieza interactiva
claude-maintenance --quiet   # Solo health score
```

**Ventajas del modo standalone:**
- No requiere entrar a Claude (ejecución inmediata)
- No consume tokens de API
- Puede agregarse a cron/hooks externos
- Útil para monitoreo preventivo antes de iniciar Claude

### Configuración del comando standalone

El wrapper está instalado en: `~/.local/bin/claude-maintenance`

**Si el comando no funciona**, agrega `~/.local/bin` a tu PATH:

```bash
# En ~/.zshrc (si usas zsh)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# En ~/.bashrc (si usas bash)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Verificar instalación:**
```bash
which claude-maintenance
# Debe mostrar: /Users/sambler/.local/bin/claude-maintenance
```

## Instrucciones para Claude (modo --cleanup)

Cuando el usuario ejecute `/session-health --cleanup` desde Claude:

### Paso 1: Obtener lista de sesiones
```bash
~/.claude/skills/session-health/check.sh --list-json
```

### Paso 2: Mostrar lista como Insight
**IMPORTANTE:** NO usar AskUserQuestion. Mostrar la lista completa como texto formateado:

```
`★ Sesiones disponibles ─────────────────────────`
#   Tamaño    Fecha       Archivo
─────────────────────────────────────────────────
1   5.7 MB    01/02 hoy   40ca17c2... ⚠️ GRANDE
2   3.0 MB    01/02 hoy   baf9ed95... 📍 ACTUAL
3   1.7 MB    01/02 hoy   64c229df...
...
10    4 KB    31/01 ayer  50dccce5...
─────────────────────────────────────────────────
Total: 10 sesiones (12 MB)
`─────────────────────────────────────────────────`

**Escribe los números a eliminar:**
- Individuales: `1,3,5`
- Rango: `4-10`
- Combinar: `1,4-7,9`
- Cancelar: `q`
```

### Paso 3: Esperar input del usuario
El usuario escribirá los números directamente en el chat.

### Paso 4: Ejecutar eliminación
```bash
~/.claude/skills/session-health/check.sh --delete <indices>
```
Donde `<indices>` son los números proporcionados por el usuario.

### Paso 5: Mostrar resultado
El comando mostrará las sesiones eliminadas y el nuevo estado de salud.

## Limitaciones conocidas

**`--resume` no funciona para compactar sesiones específicas:**

Hay dos bugs conocidos que impiden usar `claude --resume <id>` para cargar y compactar sesiones:

1. **Issue #18311** - `sessions-index.json` desincronizado, el picker no encuentra sesiones
2. **Issue #22107** - Bug en v2.1.27+ que pierde ~96% del contexto al resumir

Por esto, la única opción para sesiones grandes es **eliminarlas** con `--cleanup`.

## Referencias

- [Bug #22041](https://github.com/anthropics/claude-code/issues/22041) - CLI hangs at 99% CPU on startup
- [Bug #18311](https://github.com/anthropics/claude-code/issues/18311) - --resume "No conversations found"
- [Bug #22107](https://github.com/anthropics/claude-code/issues/22107) - --resume pierde contexto
- [Docs cleanupPeriodDays](https://code.claude.com/docs/en/settings)
- APRENDIZAJE-COMPLETO.md (sección Performance)
