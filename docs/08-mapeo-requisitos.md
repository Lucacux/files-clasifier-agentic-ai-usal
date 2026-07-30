# 08 — Mapeo de requisitos de la consigna

Trazabilidad punto por punto entre lo que pide la cátedra y dónde está implementado.

**Estado:** ⬜ pendiente · 🟨 en curso · ✅ completo
*(Esta tabla se actualiza en cada Pull Request que cierra un requisito.)*

---

## ⚙️ Requerimientos funcionales

### 1. Automatización

| Requisito | Cómo se cumple | Dónde | Estado |
|---|---|---|---|
| Ejecución automática sin intervención constante | Daemon bajo systemd, arranque al boot, reindexado periódico por timer | `daemon.py`, `deploy/archivistad.service`, `deploy/archivista-scan.timer` | ⬜ |
| Reacción ante eventos del sistema | `inotify` sobre las carpetas observadas: `IN_CLOSE_WRITE`, `IN_MOVED_TO`, `IN_CREATE` | `watcher/` | ⬜ |

### 2. Gestión de archivos

| Requisito | Cómo se cumple | Dónde | Estado |
|---|---|---|---|
| Detectar archivos nuevos o modificados | Watcher + debouncer que espera a que el archivo esté estable | `watcher/` | ⬜ |
| Clasificarlos según criterios definidos | Clasificador por reglas (extensión, MIME real, patrones) + clasificación por contenido con IA | `classify/rules.py`, `classify/ai.py` | ⬜ |
| Moverlos o reorganizarlos | Movimiento atómico con preservación de permisos y resolución de colisiones | `fsops/` | ⬜ |

### 3. Integración de IA

La consigna pide **al menos una** de las cuatro tareas. Implementamos **las cuatro**.

| Tarea | Cómo se cumple | Dónde | Estado |
|---|---|---|---|
| Clasificación por contenido | El modelo recibe texto extraído + metadatos y devuelve categoría, confianza y justificación en JSON validado | `classify/ai.py` | ⬜ |
| Generación de resúmenes | Perfil Estudiante: genera `<archivo>.resumen.md` por cada documento | `profiles/student.py` | ⬜ |
| Generación de contenido | Perfil Profesor: genera y mantiene un `INDICE.md` del material de cada carpeta | `profiles/teacher.py` | ⬜ |
| Toma de decisiones sobre organización | El modelo propone la ruta destino y el nombre normalizado, considerando el árbol de carpetas existente | `classify/ai.py`, `profiles/` | ⬜ |

**Modelo usado:** local vía Ollama, no API externa. Justificación en
[ADR-0001](adr/0001-ia-local-con-ollama.md).

### 4. Perfiles de usuario

| Requisito | Cómo se cumple | Dónde | Estado |
|---|---|---|---|
| Al menos un perfil configurable | Dos perfiles completos: 🎓 Estudiante y 👨‍🏫 Profesor | `profiles/` | ⬜ |
| Cada perfil modifica el comportamiento | Cambian el árbol destino, la acción extra generada, la política de renombrado y el umbral de confianza. Ver la tabla comparativa en [`01-arquitectura.md` §2.7](01-arquitectura.md#27-motor-de-perfiles) | `profiles/` | ⬜ |
| Conmutación de perfil | Por config, con recarga en caliente vía `SIGHUP` o `archivista reload`; se puede sobreescribir por carpeta | `config/`, `daemon.py` | ⬜ |

### 5. Generación de resultados

| Salida | Dónde queda | Estado |
|---|---|---|
| Archivos organizados en carpetas | Árbol destino según perfil | ⬜ |
| Archivos generados automáticamente | Resúmenes (`*.resumen.md`) e índices (`INDICE.md`) | ⬜ |
| Logs del sistema | Log operativo (`journalctl -u archivistad`) + log de auditoría JSONL append-only | ⬜ |
| Notificaciones | `notify-send` cuando hay sesión gráfica; resumen periódico en el log si no la hay | ⬜ |

---

## 🧱 Requerimientos técnicos

### 1. Conceptos de Sistemas Operativos

Se piden **al menos 3 de 7**. Usamos **7 de 7**. Trazabilidad completa en
[`02-conceptos-so.md`](02-conceptos-so.md).

| # | Concepto | Dónde | Estado |
|---|---|---|---|
| 1 | Procesos y/o hilos | Pool de workers + hilos de watcher e IPC; Ollama como proceso separado | ⬜ |
| 2 | Manejo del sistema de archivos | `fsops/`: `stat`, `rename`, cruce de filesystems, MIME por magic bytes | ⬜ |
| 3 | Permisos de archivos | Preservación de modo/propietario, `umask` del servicio, ACLs, socket `0660` | ⬜ |
| 4 | Comunicación entre procesos (IPC) | Socket Unix CLI↔daemon, señales, HTTP sobre loopback al modelo | ⬜ |
| 5 | Automatización mediante eventos | `inotify` | ⬜ |
| 6 | Scheduling / ejecución programada | `systemd.timer` de reindexado con `Persistent=true` | ⬜ |
| 7 | Scripts de sistema | `scripts/bootstrap-server.sh`, `deploy/install.sh`, `scripts/demo.sh` | ⬜ |

### 2. Ejecución como servicio

| Requisito | Cómo se cumple | Estado |
|---|---|---|
| Proceso en background (daemon/servicio) | Unidad systemd `archivistad.service`, `Type=notify`, arranque al boot | ⬜ |
| Iniciable/detenible manualmente | `systemctl start/stop/reload archivistad`; también `archivista pause/resume` vía CLI | ⬜ |

### 3. Manejo de concurrencia

| Requisito | Cómo se cumple | Estado |
|---|---|---|
| Procesar múltiples archivos | Pool de N hilos worker sobre una cola thread-safe | ⬜ |
| Evitar bloqueos o errores por concurrencia | Conjunto de rutas en vuelo con lock, `flock` sobre archivos, escrituras atómicas, PID lock de instancia única. Tabla completa en [`01-arquitectura.md` §4](01-arquitectura.md#4-modelo-de-concurrencia) | ⬜ |

### 4. Configuración

| Requisito | Cómo se cumple | Estado |
|---|---|---|
| Mecanismo de configuración | `archivista.yaml` validado por esquema + overrides por variables de entorno | ⬜ |
| CLI | `archivista` con subcomandos (`status`, `pending`, `approve`, `scan`, `reload`, …) | ⬜ |

Ejemplo mínimo, equivalente al de la consigna:

```yaml
profile: estudiante
watch:
  - path: /home/demo/Downloads
```

Configuración completa comentada en [`config/archivista.example.yaml`](../config/archivista.example.yaml).

### 5. Integración con IA

| Requisito | Cómo se cumple | Estado |
|---|---|---|
| APIs externas o modelos locales | **Modelo local** vía Ollama sobre `127.0.0.1:11434` | ⬜ |
| Manejo de requests/responses | Cliente HTTP con prompt estructurado y validación de esquema JSON de la respuesta | ⬜ |
| Tratamiento de errores | Timeout configurable, reintentos con backoff exponencial, circuit breaker tras K fallos, degradación a clasificación por reglas, caché por hash para no repetir inferencias | ⬜ |

---

## Más allá de lo pedido

| Extra | Por qué lo agregamos |
|---|---|
| Log de auditoría append-only con `undo` | Un sistema que mueve archivos ajenos tiene que ser reversible y auditable |
| Cola de aprobación para operaciones destructivas | Ningún borrado automático. [ADR-0005](adr/0005-borrado-con-aprobacion-humana.md) |
| Sandbox de rutas con protección contra traversal y symlinks | Un bug de rutas en un proceso que mueve archivos es una vulnerabilidad, no un bug |
| Fallback completo sin IA | El sistema tiene que funcionar aunque el modelo no esté disponible |
| Usuario dedicado para la cátedra con acceso de sólo lectura | Verificabilidad: [`05-acceso-profesor.md`](05-acceso-profesor.md) |
| ADRs de todas las decisiones no triviales | El "por qué" se pierde si no se escribe cuando se decide |
