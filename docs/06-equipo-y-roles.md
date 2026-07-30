# 06 — Equipo y roles

## Criterio de reparto

El proyecto se dividió en **seis áreas con la menor superficie de contacto posible entre
ellas**. Cada área tiene un dueño único, interfaces definidas de antemano y puede avanzar en
paralelo sin esperar a las demás.

Tres criterios guiaron la asignación:

1. **Aprovechar experiencia previa.** Lo que toca sistema operativo de verdad (systemd,
   permisos, ACLs, hardening) va a quien ya administra Linux.
2. **Nadie queda bloqueado esperando a otro.** Los contratos entre módulos (formato de
   config, esquema del evento, protocolo IPC) se definen en M0, y a partir de ahí cada uno
   puede trabajar contra una interfaz estable.
3. **Todos tocan algo de sistema operativo.** No hay un rol "sólo documentación" ni un rol
   "sólo Python". La materia es Sistemas Operativos: cada integrante tiene al menos un
   concepto de la lista bajo su responsabilidad.

---

## Integrantes

### Luca Lombardo — Infraestructura y SO · *Project Manager*

**Área:** servidor, systemd, permisos, seguridad de rutas, despliegue
**Conceptos de SO:** permisos de archivos, ejecución programada, scripts de sistema

Provisiona y mantiene el servidor Debian, define usuarios/grupos/ACLs, escribe las unidades
de systemd (servicio + timer), implementa el sandbox de rutas y la preservación de permisos,
y produce la guía de instalación reproducible. Como PM, mantiene el tablero, arbitra
decisiones de arquitectura y hace de revisor por defecto cuando nadie más está disponible.

*Perfil: 3 años usando Linux como sistema principal, experiencia previa en infraestructura.*

---

### Agustín Gil — Watcher, concurrencia y filesystem

**Área:** inotify, debounce, cola de trabajo, pool de workers, operaciones sobre archivos
**Conceptos de SO:** eventos del kernel, hilos, sincronización, sistema de archivos

Es el corazón del sistema y la parte técnicamente más delicada: traducir eventos del kernel a
trabajo, procesarlo en paralelo sin condiciones de carrera, y mover archivos de forma atómica
sin perder ni pisar nada. También escribe los tests de integración end-to-end.

*Perfil: 2 años con Linux.*

---

### Emma Tamborini — Capa de Inteligencia Artificial

**Área:** integración con el modelo local, prompts, extracción de contenido, caché
**Conceptos de SO:** IPC (HTTP sobre loopback), manejo de errores de servicios externos

Instala y evalúa el modelo, diseña los prompts con salida JSON estructurada y validación, e
implementa el cliente con timeouts, reintentos, *circuit breaker* y caché por hash. También
la extracción de texto de PDF, DOCX y demás formatos. Es la dueña del punto que la consigna
llama "tratamiento de errores (timeouts, fallos, etc.)".

---

### Zahira Dellosa — Perfiles, configuración y clasificación

**Área:** esquema de config, motor de perfiles, clasificador por reglas, generación de contenido
**Conceptos de SO:** manejo del sistema de archivos, taxonomías de tipos MIME

Define cómo se configura el sistema y cómo el perfil activo cambia su comportamiento — el
requisito 4 de la consigna, completo. Implementa el clasificador determinístico que actúa
como atajo y como red de seguridad de la IA, y la generación de resúmenes (Estudiante) e
índices de material (Profesor).

---

### Ginés Casajoana — Daemon, IPC y CLI

**Área:** ciclo de vida del proceso, señales, socket Unix, línea de comandos, cola de aprobación
**Conceptos de SO:** procesos, señales, IPC, permisos sobre el socket

Convierte el código en un servicio de verdad: arranque, apagado ordenado, manejo de
`SIGTERM`/`SIGHUP`, PID lock para instancia única. Implementa el canal de control por socket
Unix y el CLI que lo consume, incluyendo la cola de aprobación de operaciones destructivas.
Es el dueño del requisito "ejecución como servicio, iniciable y detenible manualmente".

---

### Santiago Arriaga — Observabilidad, CI/CD y entrega

**Área:** logging, auditoría, notificaciones, integración continua, demo y documentación final
**Conceptos de SO:** rotación de logs, notificaciones de escritorio, tooling

Hace que el sistema sea **demostrable**, que es la mitad de la nota: log estructurado, log de
auditoría append-only que habilita el `undo`, rotación con logrotate, notificaciones. Además
monta el CI, el script de demo para la cátedra y el informe final de entrega.

---

## Matriz de responsabilidad

Leyenda: **R** = responsable · **C** = consultado · **I** = informado

| Área | Luca | Agustín | Emma | Zahira | Ginés | Santiago |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Servidor y systemd | **R** | C | I | I | C | I |
| Permisos y seguridad de rutas | **R** | C | I | I | C | I |
| Watcher inotify | C | **R** | I | I | I | I |
| Concurrencia y cola | C | **R** | C | I | C | I |
| Operaciones de filesystem | C | **R** | I | C | I | I |
| Modelo de IA y prompts | I | I | **R** | C | I | I |
| Extracción de contenido | I | C | **R** | C | I | I |
| Configuración | C | C | C | **R** | C | I |
| Perfiles de usuario | I | I | C | **R** | C | I |
| Clasificación por reglas | I | C | C | **R** | I | I |
| Daemon y señales | C | C | I | I | **R** | I |
| IPC y CLI | C | I | I | C | **R** | C |
| Cola de aprobación | C | C | I | I | **R** | C |
| Logging y auditoría | C | C | C | C | C | **R** |
| CI/CD | C | I | I | I | I | **R** |
| Demo y documentación de entrega | C | C | C | C | C | **R** |
| Gestión del proyecto | **R** | I | I | I | I | I |

---

## Contratos entre áreas

Estas son las interfaces que **se definen en el milestone M0 y después no cambian sin
avisar**. Son lo que permite que seis personas trabajen en paralelo.

| Contrato | Entre | Dueño |
|---|---|---|
| Esquema de `archivista.yaml` | Todos | Zahira |
| `FileEvent` (evento normalizado del watcher) | Watcher → Pipeline | Agustín |
| `Classification` (resultado: categoría, confianza, motivo) | Clasificadores → Perfiles | Zahira |
| `FsOperation` (movimiento/creación/borrado propuesto) | Perfiles → FsOps | Agustín |
| Protocolo del socket Unix (JSON por líneas) | CLI ↔ Daemon | Ginés |
| Esquema del log de auditoría (JSONL) | Todos → Auditoría | Santiago |

> Si necesitás cambiar un contrato: abrí un issue con la etiqueta `type:chore`, etiquetá a
> quien lo posee y a todos los consumidores. **No lo cambies en un PR de otra cosa.**

---

## Cómo nos coordinamos

- **Tablero:** los [issues](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues) de GitHub son la única fuente de verdad. Si no está
  en un issue, no existe.
- **Revisión semanal:** cada lunes se revisa qué se movió y qué está bloqueado.
- **Bloqueos:** se comentan en el issue **el mismo día**, con la etiqueta `blocked`. No se
  espera a la reunión.
- **Decisiones de arquitectura:** se documentan como ADR en [`docs/adr/`](adr/) antes de
  implementarse.
