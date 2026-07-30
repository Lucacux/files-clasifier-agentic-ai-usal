# ADR-0002 — Python 3.11 + `watchdog` sobre inotify

- **Estado:** Aceptada
- **Fecha:** 2026-07-29
- **Decide:** Luca Lombardo (PM)
- **Consultados:** Agustín Gil, todo el equipo

## Contexto

Hay que elegir lenguaje y la forma de consumir eventos de `inotify`. Condicionantes:

- El equipo tiene seis personas con **niveles muy distintos** de experiencia en Linux y en
  programación de sistemas.
- El plazo es el de una cursada, no el de un proyecto abierto.
- El trabajo real del sistema es I/O-bound: leer archivos, hablar HTTP con el modelo, mover
  archivos. Casi nada es CPU-bound.
- Hay que extraer texto de PDF, DOCX, XLSX y demás.

## Alternativas consideradas

### Opción A — C con la API de inotify directa

**Ventajas:** es *la* forma canónica; `inotify_init()`, `inotify_add_watch()` y `read()` sobre
el descriptor, sin capas. Máximo control y el mejor argumento "de sistemas".

**Desventajas:** el resto del sistema (cliente HTTP, parseo de JSON, extracción de PDF/DOCX,
CLI) sería enormemente más costoso. Con seis personas de experiencia dispar y el plazo de una
cursada, el proyecto no llega a terminarse. Y el trabajo se concentraría en resolver
problemas ya resueltos en vez de en el diseño del sistema.

### Opción B — Bash + `inotifywait`

**Ventajas:** simplísimo de arrancar, muy poca ceremonia.

**Desventajas:** no hay forma razonable de manejar un pool de workers concurrente, estado
compartido con locks, parseo/validación de JSON ni extracción de PDF. Cumpliría el mínimo de
la consigna y nada más. Igualmente **usamos bash donde corresponde** —bootstrap, instalación,
demo— que es el concepto 7 de la lista.

### Opción C — Go

**Ventajas:** binario único sin dependencias, concurrencia excelente, buen soporte de
syscalls.

**Desventajas:** nadie del equipo lo conoce lo suficiente. La curva de aprendizaje se comería
tiempo que necesitamos para el diseño del sistema. Además el ecosistema de extracción de
texto de PDF/OOXML es notablemente más pobre que el de Python.

### Opción D — Python 3.11 + `watchdog`

**Ventajas:**

- Todo el equipo puede contribuir desde el primer día.
- Biblioteca estándar muy fuerte justo donde la necesitamos: `os`, `stat`, `shutil`,
  `signal`, `socket`, `threading`, `queue`, `fcntl.flock`. Los conceptos de SO se usan
  **directamente**, no a través de un framework.
- Ecosistema maduro para extracción de texto y clientes HTTP.
- `watchdog` es un envoltorio delgado sobre `inotify`; se puede inspeccionar el descriptor
  del proceso y ver los watches reales del kernel.

**Desventajas:**

- El GIL limita el paralelismo de CPU. **No nos afecta**: el trabajo es I/O-bound y el cómputo
  pesado corre en otro proceso (Ollama).
- Requiere entorno Python en el servidor: una dependencia más que un binario estático.
- `watchdog` abstrae inotify, lo que podría leerse como "no usar el concepto de verdad".

## Decisión

**Opción D: Python 3.11 con `watchdog` como capa sobre inotify.**

Sobre la objeción de que `watchdog` "esconde" inotify: la abstracción es delgada y verificable.
En el servidor se puede confirmar que los watches son reales del kernel:

```bash
sudo cat /proc/$(pgrep -f archivistad)/fdinfo/* | grep -A2 inotify
```

Y el diseño trata explícitamente las particularidades de inotify que un envoltorio no resuelve
por vos: la no-recursividad, el límite de `max_user_watches`, el desbordamiento de la cola
(`IN_Q_OVERFLOW`), la diferencia entre `IN_MODIFY` e `IN_CLOSE_WRITE`, y los eventos que el
propio daemon se causa al mover archivos. Eso está documentado en
[`02-conceptos-so.md` §5](../02-conceptos-so.md#5-eventos-inotify) y es lo que demuestra que
entendimos el mecanismo, no la biblioteca.

## Consecuencias

### Positivas

- Las seis personas pueden trabajar en paralelo desde el día uno.
- Los conceptos de SO se usan con la biblioteca estándar, sin intermediarios.
- Ecosistema resuelto para extracción de contenido y HTTP.
- Tests y CI baratos de montar.

### Negativas / costos que aceptamos

- Sin paralelismo real de CPU dentro del daemon (irrelevante para este workload).
- El servidor necesita Python 3.11+ y un entorno virtual.
- Distribución más pesada que un binario único.

### Qué invalidaría esta decisión

Que el perfilado muestre que el daemon en sí es el cuello de botella. Es muy improbable: el
tiempo dominante es la inferencia del modelo, medida en segundos, contra un overhead de Python
medido en milisegundos.
