# ADR-0004 — Socket de dominio Unix para la comunicación CLI ↔ daemon

- **Estado:** Aceptada
- **Fecha:** 2026-07-29
- **Decide:** Luca Lombardo (PM)
- **Consultados:** Ginés Casajona

## Contexto

El daemon corre en background. El usuario necesita consultarlo y darle órdenes desde la
terminal: ver estado, listar operaciones pendientes, aprobar un borrado, forzar un
reindexado, recargar la configuración.

Hace falta un canal de comunicación entre dos procesos. Requisitos:

- Bidireccional con respuesta (no alcanza con "avisar", hay que **consultar**).
- Controlable por permisos: no cualquier usuario de la máquina debería poder ordenarle al
  daemon que mueva archivos.
- Sin exponer nada a la red.
- La consigna pide IPC explícitamente como uno de los conceptos.

## Alternativas consideradas

### Opción A — Sólo señales (`SIGHUP`, `SIGUSR1`)

**Ventajas:** el mecanismo IPC más elemental de Unix, cero infraestructura.

**Desventajas:** unidireccional y sin carga útil. Se puede decir "recargá", pero no
"¿cuál es tu estado?" ni "aprobá la operación 7". El control de acceso es el de `kill(2)`:
mismo usuario o `root`, sin granularidad.

**Igual las usamos**, para lo que sirven: `SIGTERM` para apagado ordenado y `SIGHUP` para
recarga de config, porque es lo que `systemctl reload` espera.

### Opción B — Socket TCP en localhost

**Ventajas:** trivial de implementar, herramientas de sobra (`curl`), portable.

**Desventajas:**

- **Ocupa un puerto y es accesible para cualquier proceso de la máquina.** Sin autenticación
  propia, cualquier usuario local puede darle órdenes al daemon.
- Un error de configuración (bind en `0.0.0.0` en vez de `127.0.0.1`) expone el control del
  daemon a la red. Es un fallo clásico y silencioso.
- Overhead innecesario de la pila TCP para dos procesos en la misma máquina.

### Opción C — FIFO / named pipes

**Ventajas:** simple, con permisos de filesystem.

**Desventajas:** para request/response hacen falta **dos** FIFOs y un esquema propio de
correlación de mensajes. Con múltiples clientes concurrentes se vuelve frágil rápido. Es
reimplementar mal lo que un socket ya da.

### Opción D — Socket de dominio Unix

**Ventajas:**

- **El control de acceso es el permiso del inodo del socket.** `0660 root:archivista`
  significa que sólo quien esté en el grupo `archivista` puede hablarle al daemon: control de
  acceso gratis, dado por el sistema de archivos.
- No ocupa puerto ni es accesible desde la red, por construcción. No hay error de
  configuración posible que lo exponga.
- Request/response bidireccional nativo, con múltiples clientes concurrentes.
- Más rápido que TCP: no pasa por la pila de red.
- `SO_PEERCRED` permite conocer el UID/GID/PID real del cliente, si en algún momento hiciera
  falta auditar quién pidió qué.
- Es el mecanismo que usan `systemd`, `docker`, `podman` y prácticamente todo daemon de Linux
  para su canal de control. Es la respuesta idiomática.

**Desventajas:** sólo local (que es exactamente lo que queremos) y requiere gestionar el ciclo
de vida del archivo de socket, incluyendo limpiar el socket huérfano tras un cierre abrupto.

## Decisión

**Opción D: socket de dominio Unix en `/run/archivista/archivistad.sock`**, complementado con
**señales** para el ciclo de vida del proceso.

| Mecanismo | Para qué |
|---|---|
| Socket Unix | Comandos con respuesta: `status`, `pending`, `approve`, `undo`, `scan`, `pause` |
| `SIGTERM` | Apagado ordenado (lo envía `systemctl stop`) |
| `SIGHUP` | Recarga de configuración (lo envía `systemctl reload`) |

Protocolo: **una línea JSON por request, una por response**. Sin framing binario ni versionado
complejo; para el alcance del proyecto alcanza y sobra, y se puede depurar a mano:

```bash
echo '{"cmd":"status"}' | socat - UNIX-CONNECT:/run/archivista/archivistad.sock
```

Que se pueda inspeccionar con `socat` es una ventaja concreta a la hora de demostrar el
sistema.

## Consecuencias

### Positivas

- Control de acceso delegado al filesystem: sin autenticación propia que escribir y que
  equivocar.
- Sin superficie de red.
- Cubre dos conceptos de la consigna a la vez: IPC y permisos de archivos.
- Depurable con herramientas estándar.

### Negativas / costos que aceptamos

- Sólo funciona localmente. Para control remoto habría que ir por SSH, que es lo correcto de
  todos modos.
- Hay que manejar el socket huérfano: si el daemon muere sin limpiar, el archivo queda. El
  arranque detecta ese caso y lo elimina si nadie escucha del otro lado.
- `/run` es `tmpfs`: el directorio se pierde en cada reinicio. Se recrea con
  `RuntimeDirectory=archivista` en la unidad de systemd, que además le pone dueño y permisos
  correctos automáticamente.

### Qué invalidaría esta decisión

Que se necesitara control remoto del daemon desde otra máquina sin pasar por SSH. No está en
el alcance del proyecto.
