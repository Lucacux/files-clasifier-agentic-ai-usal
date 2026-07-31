# 09 — Guía de prompts para Claude Code

Cómo darle órdenes a Claude Code para trabajar en este proyecto sin que el resultado sea código
que parece bien y no funciona.

> **Regla de oro:** el issue ya es el prompt. Los issues de este repositorio tienen criterios de
> aceptación verificables, casos borde y dependencias. Tu trabajo no es reescribir eso en el
> chat: es **apuntar al issue, fijar el proceso y verificar el resultado.**

---

## 1. Lo que no hace falta explicar

En la raíz del repositorio hay un [`CLAUDE.md`](../CLAUDE.md) que Claude Code **carga solo** en
cada sesión. Ya sabe:

- qué es el proyecto y cuál es su arquitectura
- las reglas duras (nada de borrados automáticos, sandbox de rutas, fallback de IA)
- las convenciones de idioma, de código y de git
- que `make check` tiene que pasar

**No repitas nada de eso en tus prompts.** Repetir contexto que ya está cargado no lo refuerza:
diluye lo específico de tu pedido, que es lo único que Claude no puede saber.

Si notás que estás explicando lo mismo en todos los prompts, eso no va en el prompt: va en
`CLAUDE.md`. Es un archivo vivo — mejorarlo es trabajo válido y beneficia a los seis.

---

## 2. Anatomía de un prompt que funciona

Cinco partes. Las tres primeras son obligatorias.

| # | Parte | Por qué |
|---|---|---|
| 1 | **Qué** — el issue | `Implementá el issue #12` |
| 2 | **Dónde mirar primero** | Evita que reinvente lo que ya existe |
| 3 | **Cómo verificar** | Sin esto, "listo" significa "compila" |
| 4 | **Qué NO hacer** | Las restricciones negativas son las que más rinden |
| 5 | **Modo de trabajo** | Plan primero para lo grande, directo para lo chico |

### La parte 4 es la que la gente saltea

Decir qué **no** querés rinde más que agregar detalle sobre lo que sí. Ejemplos reales de este
proyecto:

```
No agregues dependencias nuevas sin justificarlo primero.
No toques los contratos del issue #6.
No refactorices código que no es parte de este issue.
No uses mocks para el filesystem: usá tmp_path real.
No implementes la generación de resúmenes todavía, eso es el issue #21.
```

Sin ese bloque, un modelo capaz tiende a "mejorar" cosas de alrededor, y terminás con un PR de
900 líneas donde 200 son tu issue y 700 son refactors que nadie pidió y que van a chocar con el
trabajo de otro.

---

## 3. El flujo de cuatro fases

No le pidas un issue entero de una. Cuatro mensajes, y revisás entre cada uno.

### Fase 1 — Plan

```
Entrá en modo plan.

Leé el issue #12 de este repositorio y los archivos de src/archivista/fsops/.
Proponé un plan de implementación.

Antes de escribir el plan, decime explícitamente:
- qué casos borde del issue te parecen más riesgosos
- qué decisiones vas a tener que tomar que el issue no especifica
- qué archivos de otros módulos vas a necesitar tocar

No escribas código todavía.
```

**Esta fase es la que más ahorra.** Un plan malo se corrige en 30 segundos; una implementación
mala basada en un malentendido se corrige en una hora. Si el plan revela que Claude entendió
otra cosa, corregís ahí y todavía no perdiste nada.

### Fase 2 — Implementación

```
El plan está bien, con dos correcciones:
- el caso de cruce de filesystems va con fsync sobre el archivo Y sobre el directorio destino
- el borrado del origen va último, después del rename

Implementalo. Escribí los tests en el mismo PR, no después.
No toques nada fuera de src/archivista/fsops/ y tests/.
```

### Fase 3 — Verificación

```
Corré `make check` y arreglá lo que falle.

Después, repasá el issue #12 criterio por criterio y decime cuáles cumplís
y cuáles no. Si alguno no está cubierto, decilo en vez de darlo por hecho.
```

Ese último renglón importa: **le da permiso explícito para decir que algo no está**. Sin eso, la
respuesta por defecto tiende al optimismo.

### Fase 4 — Entrega

```
Commiteá con Conventional Commits y abrí el PR contra main usando la plantilla
del repositorio, con `Closes #12`.

En la sección "Cómo lo probaste" poné los comandos reales que corriste, no
una descripción genérica.
```

---

## 4. Plantilla universal

Copiá, completá los corchetes, pegá.

```
Trabajá sobre el issue #[N].

Contexto que necesitás leer primero:
- [archivos o módulos relevantes]
- [el ADR que aplica, si hay]

Restricciones:
- No toques [módulos de otras personas]
- No agregues dependencias sin avisar
- [restricción específica del issue]

Definición de terminado:
- Todos los criterios de aceptación del issue cumplidos
- Tests del camino feliz y de al menos un caso de error
- `make check` en verde

Empezá en modo plan. No escribas código hasta que valide el plan.
```

---

## 5. Prompts listos por área

Uno por persona. Sirven de molde para los demás.

Ojo con el orden: los tres issues de arranque de M0 (#6, #3 y #7) son **contratos y medición**,
no implementación, y por eso tienen prompts distintos. Están primero. Los prompts por área que
vienen después son para el issue siguiente de cada uno.

### 5.1 Los tres de arranque

#### ⚙️ Agustín — Contratos de datos (#6)

```
Entrá en modo plan para el issue #6 (contratos de datos entre módulos).

Esto no es implementar: es definir las estructuras que van a usar cinco
personas más. Lo que importa es que sean estables, no que sean completas.
Si dudás entre agregar un campo ahora o después, no lo agregues: sumar un
campo opcional más adelante no rompe a nadie, cambiarle el tipo sí.

Leé antes:
- docs/01-arquitectura.md (flujo de datos)
- docs/06-equipo-y-roles.md, tabla de contratos: FileEvent y FsOperation son
  tuyos; Classification es de Zahira y el log de auditoría de Santiago

Para cada contrato quiero en el plan:
- los campos con su tipo, y para cada uno: quién lo escribe y quién lo lee
- qué es obligatorio y qué opcional, con el criterio
- cómo se serializa (van a cruzar el socket Unix y el log JSONL)
- un ejemplo concreto de cada uno, con valores reales

Usá dataclasses o pydantic, pero decidilo en el plan y justificalo: los
consumidores son el pipeline, el CLI y el log de auditoría.

No implementes el watcher acá: es el issue #9.
```

#### 🤖 Emma — Benchmark del modelo (#3)

```
Ayudame con el issue #3 (instalar el modelo local y medir la latencia real).

Antes que nada leé docs/adr/0007-modelo-local-y-presupuesto-de-inferencia.md:
la sección final tiene el protocolo de medición y los umbrales de aceptación.
Este issue no es "probar modelos": es confirmar o refutar esa ADR con números.

Lo que necesito de vos, en este orden:
1. un script reproducible (scripts/benchmark-modelo.py) que corra el protocolo
   completo contra un endpoint de Ollama y escriba los resultados en CSV
2. que separe prefill de decode usando los campos que devuelve Ollama:
   prompt_eval_count, prompt_eval_duration, eval_count, eval_duration
3. que compare think=true contra think=false, y max_content_chars 1500 contra
   4000: son las dos variables que la ADR afirma que dominan la latencia
4. que valide cada respuesta contra un esquema JSON y cuente los fallos

El corpus lo armo yo con archivos reales; el script recibe un directorio y un
CSV de categorías esperadas.

No implementes el cliente de producción acá: es el issue #17. Este script es
una herramienta de medición y puede ser todo lo feo que haga falta, pero los
números tienen que ser correctos.
```

#### 📊 Santiago — CI y protección de rama (#7)

```
Implementá el issue #7 (endurecer el CI y proteger la rama main).

Leé .github/workflows/ci.yml: ya existe y corre formato, linter, tipos, tests,
shellcheck y un verificador de enlaces internos. No lo reescribas, endurecelo.

Lo que quiero:
- caché de dependencias que funcione de verdad (hoy la clave es 'pip' a secas)
- umbral mínimo de cobertura, que falle el job si baja
- el job de shellcheck ya no puede ser opcional: hay scripts en scripts/
- separar lo que corre en cada PR de lo que corre sólo en main, si algo tarda

Sobre la protección de main, decidilo y explicámelo antes de tocar nada:
GitHub tiene branch protection clásica y rulesets, y en repos privados de
cuentas gratuitas puede que ninguna de las dos esté disponible. Averigualo
primero y, si no está disponible, escribí en el issue cuál es el plan B (por
ejemplo CODEOWNERS + acuerdo del equipo) en lugar de dejarlo a medias.

Empezá en modo plan.
```

### 5.2 Por área

### 🔧 Luca — Sandbox de rutas (#16)

```
Entrá en modo plan para el issue #16 (sandbox de rutas).

Es el issue de seguridad del proyecto: el daemon construye rutas a partir de
nombres de archivo del usuario y de categorías que inventa un LLM. Ninguna de
las dos fuentes es confiable.

Leé primero:
- docs/adr/0005-borrado-con-aprobacion-humana.md
- la sección de configuración `destination` en config/archivista.example.yaml

Requisitos que quiero explícitos en el plan:
- el orden resolve() → validar, y por qué el orden inverso es el bug clásico
- cómo sanitizás los nombres y categorías que devuelve el modelo
- cómo garantizás que esta función sea la ÚNICA puerta al filesystem

Escribí los tests de los casos maliciosos ANTES de la implementación. Están
listados en el issue: usá esos y agregá los que se te ocurran.

No escribas código hasta que valide el plan.
```

### ⚙️ Agustín — Watcher inotify (#9)

```
Implementá el issue #9 (watcher de inotify). Empezá en modo plan.

Leé antes:
- docs/02-conceptos-so.md, sección 5 (limitaciones de inotify)
- el contrato FileEvent del issue #6

Los tres casos que más me importan y que quiero ver resueltos en el plan:
1. el bucle de reprocesamiento (el daemon mueve un archivo dentro de una
   carpeta observada y se dispara a sí mismo)
2. la carrera al registrar un watch sobre un subdirectorio nuevo
3. IN_Q_OVERFLOW

Usá `watchdog`, no la API de inotify a pelo.
Los tests van con filesystem temporal real (tmp_path), no con mocks del watcher.
No implementes el debounce acá: es el issue #10.
```

### 🤖 Emma — Cliente de IA (#17)

```
Implementá el issue #17 (cliente del modelo con timeouts, reintentos y
circuit breaker). Empezá en modo plan.

La regla que gobierna todo el módulo: el sistema tiene que seguir funcionando
con el modelo caído. Nunca se bloquea la cola esperando una inferencia.

En el plan quiero ver explícito:
- qué errores son transitorios (se reintentan) y cuáles no
- cómo mantenés el estado del circuit breaker thread-safe entre workers
- qué pasa exactamente con un archivo cuando el circuito está abierto

Los tests van contra un servidor HTTP falso, no contra Ollama real: quiero
poder simular timeout, 500, conexión rechazada y respuesta truncada de forma
determinística.

No implementes el prompt de clasificación acá: es el issue #18.
```

### 📋 Zahira — Configuración (#5)

```
Implementá el issue #5 (esquema de configuración y cargador).

Es camino crítico: cinco personas están esperando este contrato, así que
priorizá que sea estable por encima de que sea completo.

Leé config/archivista.example.yaml entero: el esquema tiene que cubrirlo todo.

Requisitos que no están tan obvios en el issue:
- los mensajes de error van en español y tienen que decir QUÉ campo está mal
  y qué se esperaba, no un volcado de pydantic
- la carga tiene que poder producir una config nueva sin efectos secundarios,
  porque el daemon recarga con SIGHUP y si la nueva es inválida se descarta
- `destructive.require_approval: false` tiene que fallar la validación con un
  mensaje que explique por qué (ver ADR-0005)

Empezá en modo plan.
```

### 🖥️ Ginés — Daemon (#23)

```
Implementá el issue #23 (ciclo de vida del daemon, señales y PID lock).
Empezá en modo plan.

Leé docs/01-arquitectura.md sección 3 (diagrama de estados).

Lo que separa esto de un script y quiero ver bien resuelto:
- el apagado ordenado ante SIGTERM: dejar de encolar, ESPERAR a que los
  workers terminen lo que están haciendo, después cerrar
- por qué flock sobre el PID file y no un archivo PID a secas (hay una
  condición de carrera conocida: explicámela en el plan)
- SIGHUP con config inválida: se descarta y se sigue con la anterior

Los tests tienen que cubrir el apagado CON trabajo en curso, no sólo el
apagado en reposo.

No implementes el servidor IPC acá: es el issue #24.
```

### 📊 Santiago — Auditoría (#28)

```
Implementá el issue #28 (logging estructurado y log de auditoría).
Empezá en modo plan.

El esquema del log de auditoría está definido en el issue #8: respetalo, no
lo redefinas.

Este log es lo que le mostramos al profesor, así que:
- tiene que ser cómodo de consultar con jq
- cada entrada necesita lo suficiente para revertir la operación (lo consume
  `archivista undo`, issue #25)
- en nivel INFO no van rutas completas de archivos personales; en DEBUG sí

Decidí y justificá en el plan cómo manejás la rotación con el descriptor
abierto: copytruncate o postrotate + señal.

Test obligatorio: N hilos escribiendo a la vez producen N líneas válidas y
parseables, sin entrelazado.
```

---

## 6. Prompts de mantenimiento

### Revisar un PR de otro

```
Revisá el PR #[N] como si fueras a firmarlo.

No busques errores de tipeo. Buscá:
- ¿hace lo que dice el issue, o algo parecido?
- ¿qué pasa si el archivo desaparece a mitad de la operación?
- ¿qué pasa si el modelo tarda 40 segundos?
- ¿rompe algún contrato del issue #6?
- ¿viola alguna regla dura de CLAUDE.md?

Clasificá cada comentario con blocking: / suggestion: / question: / nit:
```

### Debuggear

```
[pegar el error o el log]

Antes de proponer un arreglo: explicame por qué pasa.
Si no estás seguro de la causa, decilo y proponé cómo confirmarla.

No quiero un parche que haga desaparecer el síntoma.
```

Ese último renglón evita el `try/except: pass` que hace pasar el test y esconde el bug.

### Cerrar un issue del todo

```
El código del issue #[N] ya está. Cerrá los cabos sueltos:

- actualizá docs/08-mapeo-requisitos.md si este issue cierra un requisito
  de la consigna
- actualizá docs/01-arquitectura.md si la implementación quedó distinta
  a lo diseñado
- si tomaste una decisión de arquitectura no trivial, escribí el ADR en
  docs/adr/ usando la plantilla

Si no corresponde ninguna de las tres, decímelo en vez de inventar cambios.
```

---

## 7. Anti-patrones

| ❌ No hagas esto | ✅ Hacé esto | Por qué |
|---|---|---|
| `Hacé el sistema de archivos` | `Implementá el issue #12` | El issue tiene 8 criterios verificables; tu frase tiene cero |
| `Implementá los issues #9, #10, #11 y #12` | Uno por vez, un PR por issue | Un PR de 900 líneas no se revisa: se aprueba a ciegas |
| `Escribí tests` (después de implementar) | `Implementalo con tests en el mismo PR` | Los tests escritos después se escriben para pasar, no para romper |
| `Arreglá el bug` | `Explicame por qué pasa, después arreglalo` | Sin diagnóstico salen parches que esconden el síntoma |
| `Hacelo lo mejor posible` | Restricciones concretas | "Lo mejor posible" se interpreta como "tocá todo" |
| Aceptar "listo" sin verificar | `Corré make check y mostrame la salida` | "Listo" y "verificado" no son lo mismo |
| Explicar la arquitectura en cada prompt | Confiar en `CLAUDE.md` | Diluye lo específico, que es lo único que aporta |

---

## 8. La verificación es tuya, no de Claude

Antes de abrir el PR, siempre:

```bash
make check                 # tiene que estar en verde, sin excepciones
git diff --stat            # ¿el tamaño tiene sentido para este issue?
git diff                   # leelo entero: es tu nombre el que va en el commit
```

Tres señales de que algo salió mal aunque los tests pasen:

- **El diff toca archivos de otra persona.** Casi siempre es alcance que se escapó.
- **Aparecieron dependencias nuevas en `pyproject.toml`** que no pediste.
- **Hay un `try/except` que no hace nada** o un test con `assert True`.

**El PR lleva tu nombre.** Si no podés explicar una línea en la revisión, esa línea no está
lista para entrar.

---

## 9. Referencia rápida

```
Entrá en modo plan. Leé el issue #N. No escribas código todavía.
    → arrancar cualquier issue no trivial

Corré make check y arreglá lo que falle.
    → antes de considerar nada terminado

Repasá el issue criterio por criterio y decime cuáles NO cumplís.
    → antes de abrir el PR

No toques nada fuera de [directorio].
    → contener el alcance

Explicame por qué pasa antes de arreglarlo.
    → cualquier bug

¿Qué decisiones tomaste que el issue no especificaba?
    → sacar a la luz las suposiciones silenciosas
```
