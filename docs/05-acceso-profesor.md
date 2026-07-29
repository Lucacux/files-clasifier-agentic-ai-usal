# 05 — Acceso y verificación para la cátedra

> Esta página está escrita **para el profesor**. El objetivo es que pueda verificar que el
> sistema hace lo que decimos que hace, de tres formas independientes y con distinto nivel de
> acceso.

---

## Resumen

| Vía | Qué requiere | Qué permite ver |
|---|---|---|
| **A. Sólo el repositorio** | Nada | Código, documentación, historial de decisiones, planificación e issues |
| **B. Demo grabada** | Nada | El sistema funcionando de punta a punta |
| **C. Acceso SSH al servidor** | Clave pública | Ejecutar la demo en vivo e inspeccionar el sistema real |

Ninguna de las tres depende de las otras. Si el servidor está caído el día de la corrección,
A y B siguen demostrando el trabajo completo.

---

## A. Verificación sólo con el repositorio

Todo lo relevante es público y legible sin ejecutar nada:

| Qué querés verificar | Dónde mirar |
|---|---|
| Que aplicamos conceptos de SO | [`02-conceptos-so.md`](02-conceptos-so.md) — tabla de trazabilidad concepto → archivo |
| Que cada requisito de la consigna está cubierto | [`08-mapeo-requisitos.md`](08-mapeo-requisitos.md) — mapeo punto por punto |
| Por qué tomamos cada decisión técnica | [`adr/`](adr/) — un documento por decisión, con alternativas descartadas |
| Cómo nos organizamos | [Issues](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues) y [Milestones](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/milestones): quién hizo qué y cuándo |
| Que el trabajo está repartido | Historial de commits y de Pull Requests |

**El historial de Git es parte de la entrega.** Cada funcionalidad entró por un Pull Request
enlazado a un issue, revisado por otra persona del equipo. Se puede reconstruir quién
escribió cada línea y con qué justificación.

---

## B. Demo grabada

Una grabación de pantalla del sistema completo en funcionamiento, sin cortes:

1. El servicio arranca y queda a la espera
2. Se copian archivos variados a la carpeta observada
3. El daemon los detecta, clasifica y mueve, en vivo
4. Se muestran los resúmenes generados por el modelo
5. Se cambia el perfil de Estudiante a Profesor y se repite: el mismo archivo va a otro lado
6. Se muestra el log de auditoría
7. Se solicita un borrado y se muestra que **requiere aprobación explícita**

> 📹 Enlace a la grabación: *pendiente — se publica acá al cerrar el milestone M4.*

---

## C. Acceso al servidor

### Credenciales

Se entregan por el canal del aula virtual junto con el trabajo:

```
Host:    <ip-o-dominio>
Usuario: profesor
Auth:    clave pública (se solicita la del profesor, o se entrega una generada)
```

```bash
ssh profesor@<ip-o-dominio>
```

Al entrar, el `motd` muestra los comandos disponibles.

### Qué puede hacer el usuario `profesor`

| Acción | Permitido | Cómo |
|---|---|---|
| Ver el estado del servicio | ✅ | `archivista status` |
| Leer el log operativo | ✅ | `journalctl -u archivistad` |
| Leer el log de auditoría | ✅ | `less /var/log/archivista/audit.jsonl` |
| Leer la configuración | ✅ | `cat /etc/archivista/archivista.yaml` |
| Ver el código instalado | ✅ | `/opt/archivista` |
| **Correr la demo completa** | ✅ | `archivista-demo` |
| Modificar la configuración | ❌ | Sólo lectura por ACL |
| Detener el servicio | ❌ | Sin `sudo` |
| Acceder a archivos de otros usuarios | ❌ | Permisos estándar de Unix |

El acceso de lectura se otorga con ACLs (`setfacl`), no dando permisos amplios ni agregando
al usuario a grupos privilegiados. Es una cuenta de auditoría, deliberadamente acotada.

### La demo interactiva

```bash
archivista-demo
```

El script (`scripts/demo.sh`) es **reproducible e idempotente**: se puede correr las veces
que haga falta y siempre parte de un estado limpio.

Qué hace, paso a paso:

```
[1/8] Restablece un entorno limpio en /home/demo
[2/8] Muestra el estado del servicio y del modelo cargado
[3/8] Perfil ESTUDIANTE
      Copia 8 archivos de prueba a /home/demo/Downloads:
        apunte-so-unidad3.pdf     trabajo-practico.docx
        foto-pizarron.jpg         planilla-notas.xlsx
        instalador.deb            paper-scheduling.pdf
        captura.png               bibliografia.txt
[4/8] Muestra en vivo cómo el daemon los detecta, clasifica y mueve
      (log de auditoría en tiempo real, en paralelo)
[5/8] Muestra el árbol resultante y abre uno de los resúmenes generados por la IA
[6/8] Perfil PROFESOR
      Cambia el perfil, recarga con SIGHUP y repite con los mismos archivos
      → el mismo material termina en una estructura distinta, orientada a la clase
[7/8] Solicita el borrado de un duplicado
      → muestra que la operación queda PENDIENTE de aprobación y no se ejecuta sola
[8/8] Resumen: archivos procesados, decisiones por IA vs por reglas, latencias, errores
```

Duración aproximada: **4 minutos**.

### Verificaciones rápidas

Si preferís comprobar cosas puntuales en vez de correr la demo entera:

```bash
# ¿Es realmente un servicio en background?
systemctl status archivistad
ps -o pid,ppid,nlwp,user,cmd -p $(pgrep -f archivistad)
#   nlwp muestra la cantidad de hilos: watcher + IPC + N workers

# ¿Usa realmente eventos del kernel y no polling?
sudo cat /proc/$(pgrep -f archivistad)/fdinfo/* | grep -A2 inotify
#   muestra los watches de inotify registrados

# ¿Existe el IPC?
ls -l /run/archivista/archivistad.sock     # socket Unix, permisos 0660

# ¿El modelo corre localmente?
systemctl status ollama
curl -s localhost:11434/api/tags | jq '.models[].name'

# ¿Está programada la ejecución periódica?
systemctl list-timers archivista-scan.timer

# ¿Qué hizo el sistema hoy?
jq -r 'select(.op=="move") | "\(.ts)  \(.decided_by)  \(.src) → \(.dst)"' \
   /var/log/archivista/audit.jsonl | tail -20
```

---

## Preguntas que anticipamos

**¿El sistema podría borrar archivos del usuario por error?**
No. Ninguna ruta de código borra archivos de forma autónoma. Las operaciones destructivas van
a una cola de aprobación y sólo se ejecutan tras confirmación explícita por CLI. La
justificación completa está en [ADR-0005](adr/0005-borrado-con-aprobacion-humana.md).

**¿Qué pasa si el modelo de IA no responde?**
El sistema degrada al clasificador por reglas y sigue funcionando. Hay timeout, reintentos
con backoff y un *circuit breaker*. Un archivo nunca queda sin procesar ni bloquea la cola
esperando a la IA.

**¿Se envía algún archivo a un servicio externo?**
No. El modelo corre localmente y escucha sólo en `127.0.0.1`. Ningún contenido de archivos
sale de la máquina. Fue una decisión de diseño explícita, no una consecuencia accidental.

**¿Y si dos archivos llegan al mismo tiempo?**
Se procesan en paralelo por el pool de workers. La protección contra condiciones de carrera
(rutas en vuelo, locks de archivo, escrituras atómicas) está detallada en
[`01-arquitectura.md` §4](01-arquitectura.md#4-modelo-de-concurrencia).

**¿Funciona en una máquina con entorno de escritorio?**
Sí. Está desarrollado sobre Debian minimal headless precisamente para demostrar que no
depende de nada gráfico, y se traslada sin cambios a una máquina con escritorio. Lo único que
se activa de más en ese caso son las notificaciones de escritorio, que están detrás de un
flag de configuración.
