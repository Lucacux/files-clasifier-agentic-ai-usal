# CLAUDE.md

Contexto del proyecto para Claude Code. Este archivo se carga automáticamente en cada sesión:
no hace falta repetir nada de acá en los prompts.

---

## Qué es este proyecto

**Archivista** — daemon de Linux que observa carpetas con `inotify`, clasifica archivos con un
modelo de IA local (Ollama) y los reorganiza según un perfil de usuario (Estudiante/Profesor).

Es el Trabajo Práctico Final de **Sistemas Operativos** (USAL). Eso condiciona dos cosas:

1. **Los conceptos de SO se usan de verdad, no se simulan.** Hilos reales, `flock` real, socket
   Unix real, permisos reales. Si hay una forma "de sistemas" y una forma "de framework" de
   resolver algo, se elige la primera y se explica por qué.
2. **Un profesor va a leer el repositorio.** El código y la documentación son parte de la nota,
   no un medio para llegar a un producto.

Documentación completa en [`docs/`](docs/). Empezá siempre por
[`docs/01-arquitectura.md`](docs/01-arquitectura.md).

---

## Reglas duras

Estas no se negocian. Violarlas es un `blocking:` automático en la revisión.

### 1. Ninguna operación destructiva es automática

`os.remove`, `os.unlink`, `shutil.rmtree`, `Path.unlink` y equivalentes **sólo** pueden aparecer
dentro del módulo que ejecuta aprobaciones ya confirmadas por el usuario.

En cualquier otro archivo del proyecto: no. Si necesitás borrar algo, encolás una propuesta en
la cola de aprobación. Ver [ADR-0005](docs/adr/0005-borrado-con-aprobacion-humana.md).

### 2. Ninguna ruta se toca sin validar contra el sandbox

Toda ruta se resuelve con `.resolve()` **primero** y se valida contra `allowed_roots`
**después**. Ese orden importa: validar antes de resolver deja pasar `Facultad/../../etc`.

Las rutas vienen de nombres de archivo que elige el usuario y de categorías que **inventa un
modelo de lenguaje**. Ninguna de las dos fuentes es confiable.

### 3. Toda llamada a la IA tiene timeout y fallback

El sistema tiene que seguir funcionando con el modelo caído. Si la IA falla, se degrada al
clasificador por reglas. **Nunca** se bloquea la cola ni se pierde un archivo esperando una
inferencia.

### 4. Toda operación sobre el filesystem se registra en auditoría

Una línea JSON append-only por operación, con lo necesario para revertirla.

### 5. Ningún secreto en el repositorio

Ni tokens, ni contraseñas, ni rutas personales reales. Todo por `.env` (que está en
`.gitignore`).

---

## Idiomas

| Qué | Idioma |
|---|---|
| `docs/`, README, issues, PRs | Español |
| Nombres de variables, funciones, clases, docstrings, comentarios | Inglés |
| Mensajes de commit | Inglés (Conventional Commits) |
| Mensajes del CLI y logs que ve el usuario | Español |

Ver [ADR-0006](docs/adr/0006-idiomas-del-proyecto.md).

---

## Comandos

```bash
make install   # instala en modo editable + hooks de pre-commit
make fmt       # formatea (ruff format + ruff check --fix)
make lint      # ruff format --check + ruff check
make types     # mypy strict sobre src/
make test      # pytest con cobertura
make check     # todo lo anterior — es exactamente lo que corre el CI
```

**`make check` tiene que pasar antes de decir que una tarea está terminada.** No "debería
pasar": corrélo.

---

## Estructura

```
src/archivista/
├── cli.py              # CLI            (Ginés)
├── daemon.py           # ciclo de vida, señales, PID lock   (Ginés)
├── ipc/                # socket Unix    (Ginés)
├── watcher/            # inotify + debounce      (Agustín)
├── pipeline/           # cola y workers          (Agustín)
├── fsops/              # movimientos, permisos, sandbox   (Agustín + Luca)
├── classify/
│   ├── rules.py        # clasificador determinístico   (Zahira)
│   ├── extract.py      # extracción de texto/metadatos (Emma)
│   └── ai.py           # cliente del modelo local      (Emma)
├── profiles/           # Estudiante / Profesor   (Zahira)
├── config/             # carga y validación      (Zahira)
└── observability/      # logging y auditoría     (Santiago)
```

---

## Contratos entre módulos

Las estructuras que se pasan entre áreas (`FileEvent`, `FileContext`, `Classification`,
`FsOperation`, `AuditRecord`) están definidas en el issue #6 y son **estables**.

Si tu tarea parece necesitar un campo nuevo en alguno de estos contratos: **pará y avisá.**
No lo agregues por tu cuenta dentro de un PR de otra cosa — rompe a los otros cinco.

---

## Convenciones de código

- Python 3.11, type hints completos (`mypy --strict` tiene que pasar)
- `pathlib.Path`, nunca `os.path` ni strings para rutas
- Excepciones propias por dominio, no `Exception` genérica
- Los módulos que procesan archivos del usuario **no pueden lanzar excepciones hacia afuera**:
  un PDF corrupto no puede tumbar un worker
- Los tests cubren el camino feliz **y** al menos un caso de error
- El código concurrente lleva un comentario que explica **qué protege cada lock**

---

## Git

- Rama por issue: `<tipo>/<nº-issue>-<descripción-corta>` (ej. `feat/12-movimiento-atomico`)
- Conventional Commits en inglés: `feat(watcher): debounce inotify events`
- Un issue = una rama = un PR, enlazado con `Closes #N`
- **Nunca push directo a `main`**
- PRs de menos de 400 líneas de diff

Detalle completo en [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Qué hacer cuando algo no está claro

**Preguntá antes de inventar.** Este proyecto tiene seis personas trabajando en paralelo contra
interfaces compartidas: una suposición silenciosa sobre un contrato ajeno se propaga y rompe
trabajo de otros.

Si el issue no especifica algo y hay más de una lectura razonable, decilo explícitamente en vez
de elegir en silencio.
