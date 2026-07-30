# 02 — Conceptos de Sistemas Operativos aplicados

La consigna exige **al menos 3** de los 7 conceptos listados. Este proyecto usa **los 7**, y
no de forma decorativa: cada uno resuelve un problema real que aparece al construir el
sistema. Esta tabla es la trazabilidad para la corrección.

| # | Concepto | Dónde vive | Qué problema resuelve |
|---|---|---|---|
| 1 | **Procesos y/o hilos** | `pipeline/`, `daemon.py` | Un hilo watcher + pool de N hilos worker + hilo de IPC dentro del daemon; Ollama corre como proceso separado. Permite procesar varios archivos a la vez sin bloquear la recepción de eventos. |
| 2 | **Manejo del sistema de archivos** | `fsops/` | Recorrido de árboles, `stat`, detección de MIME por *magic bytes*, movimientos atómicos con `rename()`, manejo de cruce entre filesystems, resolución de colisiones. |
| 3 | **Permisos de archivos** | `fsops/permissions.py`, `deploy/` | Preservación de modo/propietario al mover; `umask` del servicio; socket con permisos `0660` y grupo dedicado; usuario `profesor` con acceso de sólo lectura vía ACLs. |
| 4 | **Comunicación entre procesos (IPC)** | `ipc/` | Socket de dominio Unix entre el CLI y el daemon; señales (`SIGTERM`, `SIGHUP`) como canal de control; HTTP sobre loopback contra el proceso de inferencia. |
| 5 | **Automatización mediante eventos** | `watcher/` | `inotify` vía `watchdog`: el daemon reacciona a `IN_CLOSE_WRITE` e `IN_MOVED_TO` en lugar de hacer *polling*, que es lo que hace la diferencia entre un servicio y un `cron` disfrazado. |
| 6 | **Scheduling / ejecución programada** | `deploy/archivista-scan.timer` | Un `systemd.timer` dispara un reindexado periódico para reconciliar lo que inotify pueda haber perdido (cola del kernel saturada, montajes de red, daemon caído). |
| 7 | **Scripts de sistema (bash/shell)** | `scripts/`, `deploy/install.sh` | Bootstrap del servidor, instalación del servicio, script de demo para la cátedra, backup del log de auditoría. |

---

## Detalle por concepto

### 1. Procesos y hilos

```
archivistad (PID 1 del servicio)
├── MainThread        → señales, ciclo de vida, apagado ordenado
├── watcher           → lee eventos de inotify y los encola
├── ipc-server        → acepta conexiones del CLI
├── worker-0..N       → consumen la cola y procesan archivos
└── (subproceso)      → ninguno propio; Ollama es un servicio aparte gestionado por systemd
```

La justificación de hilos sobre procesos está en
[`01-arquitectura.md` §4](01-arquitectura.md#4-modelo-de-concurrencia): el trabajo es
I/O-bound, y el cómputo pesado ya vive en otro proceso.

### 2. Sistema de archivos

El detalle no obvio es el **movimiento atómico**. `os.rename()` es atómico sólo dentro del
mismo filesystem; si `~/Downloads` y `~/Documentos` están en particiones distintas, falla con
`EXDEV`. La implementación detecta ese caso y hace copia a temporal + `fsync()` + `rename()`,
de modo que el destino nunca es visible a medio escribir.

### 3. Permisos

Tres niveles:

- **Del servicio:** corre como usuario sin privilegios `archivista`, con `umask 0027`. La
  unidad de systemd usa `ProtectSystem=strict`, `PrivateTmp=yes` y `ReadWritePaths=` acotado
  únicamente a las carpetas configuradas.
- **De los archivos:** al mover se conservan modo y propietario originales. Un archivo que
  era `0600` no termina siendo `0644` por pasar por el organizador.
- **Del acceso:** el socket de control es `0660 root:archivista`. Quien no esté en el grupo
  no puede hablarle al daemon. El usuario `profesor` recibe lectura sobre logs y config por
  ACL (`setfacl`), sin poder modificar nada.

### 4. IPC

Tres mecanismos distintos, cada uno donde corresponde:

| Mecanismo | Entre quiénes | Para qué |
|---|---|---|
| Socket Unix | CLI ↔ daemon | Comandos y consultas con respuesta |
| Señales | systemd/usuario → daemon | `SIGTERM` apagado ordenado, `SIGHUP` recarga de config |
| HTTP sobre loopback | daemon ↔ Ollama | Inferencia |

Elegimos socket Unix sobre TCP a propósito: no expone puerto de red, y el control de acceso
lo da el filesystem. Ver [ADR-0004](adr/0004-ipc-socket-unix.md).

### 5. Eventos (inotify)

Lo importante es lo que **no** hacemos: no hay polling. El daemon está bloqueado en `read()`
sobre el descriptor de inotify, consumiendo 0% de CPU hasta que el kernel le entrega un
evento.

Limitaciones de inotify que el diseño contempla explícitamente:

| Limitación | Cómo la manejamos |
|---|---|
| No es recursivo: hay que registrar un watch por directorio | El watcher registra watches nuevos al detectar `IN_CREATE` sobre directorios |
| Límite de watches (`fs.inotify.max_user_watches`) | Se sube vía `sysctl` en el bootstrap y se documenta |
| La cola del kernel puede desbordar (`IN_Q_OVERFLOW`) | Se detecta y dispara un reescaneo completo de la carpeta afectada |
| No funciona sobre NFS ni algunos montajes de red | Documentado como limitación conocida; el timer periódico cubre el caso |
| Un `mv` dentro de la carpeta observada dispara eventos que el propio daemon causó | Las rutas que el daemon acaba de escribir se ignoran durante una ventana corta, para evitar bucles de reprocesamiento |

### 6. Ejecución programada

`archivista-scan.timer` corre cada hora y llama a `archivista scan --all`. No es la vía
principal (esa es inotify) sino la **red de seguridad**: reconcilia cualquier cosa que el
mecanismo de eventos se haya perdido. Usa `Persistent=true`, así que si la máquina estuvo
apagada a la hora prevista, el reindexado se ejecuta en el próximo arranque.

### 7. Scripts de sistema

| Script | Qué hace |
|---|---|
| `scripts/bootstrap-server.sh` | Deja un Debian minimal listo: paquetes, usuarios, grupos, `sysctl`, Ollama |
| `deploy/install.sh` | Instala el paquete, las unidades de systemd y logrotate |
| `scripts/demo.sh` | Genera archivos de prueba y muestra el sistema clasificándolos en vivo |
| `scripts/backup-audit.sh` | Comprime y rota el log de auditoría |
