# ADR-0007 — Qwen3.5 en dos niveles y presupuesto de inferencia explícito

- **Estado:** Aceptada
- **Fecha:** 2026-07-29
- **Decide:** Luca Lombardo (PM)
- **Consultados:** Emma Tamborini (dueña de la capa de IA), Zahira Dellosa (config)
- **Relacionada con:** [ADR-0001](0001-ia-local-con-ollama.md) (elige Ollama),
  [ADR-0003](0003-infraestructura-servidor.md) (elige el hardware)

## Contexto

ADR-0001 decidió *modelo local vía Ollama* pero dejó abierto **cuál** modelo. La tabla de
candidatos de [`03-entorno-servidor.md`](../03-entorno-servidor.md) §3 proponía
`qwen2.5:3b-instruct-q4_K_M` y `llama3.2:3b`. Ambos son de mediados de 2024: a julio de 2026
están dos generaciones atrás y hay modelos de tamaño equivalente sensiblemente mejores en
seguimiento de instrucciones y en salida estructurada, que es exactamente lo que este proyecto
necesita.

Hay que cerrar la decisión ahora, y no cuando el benchmark termine, por una razón de
dependencias: el nombre del modelo es un **valor del contrato de configuración** (`ai.model` en
`archivista.yaml`, issue #5) y el presupuesto de latencia es el marco en el que Emma diseña el
prompt (#18) y el cliente con timeouts y *circuit breaker* (#17). Tres issues esperan este dato.

### Restricciones reales

| Restricción | Origen |
|---|---|
| **CPU-only**, sin GPU asumida | ADR-0003 |
| ≤ 8 GiB de RAM para toda la capa de IA | ADR-0003 |
| Salida **JSON validable contra un esquema** | Requisito de #18: categorías inventadas o JSON roto rompen el pipeline |
| Sin internet durante la demo | ADR-0001 |
| Licencia compatible con un repositorio abierto | El repo es del equipo y lo audita la cátedra |
| Debe soportar **tool calling** | La capa de IA es agéntica por diseño: hoy clasifica, pero el pipeline está pensado para que el modelo elija operaciones, no sólo etiquetas |
| Ha de tener una variante más chica y otra más grande | La estrategia de dos niveles de ADR-0001 exige una familia, no un modelo suelto |

### El hallazgo que cambia el planteo: la latencia no la manda el tamaño del modelo

La tabla original razonaba "modelo de 3B ⇒ 1–3 s". Eso es engañoso. En CPU el tiempo de una
inferencia se parte en dos fases con velocidades muy distintas:

```
latencia ≈ (tokens_de_entrada / velocidad_de_prefill) + (tokens_de_salida / velocidad_de_decode)
```

Con `max_content_chars: 4000` (el valor que traía la config de ejemplo), la entrada son unos
**1100–1300 tokens** de texto extraído más ~400 de prompt de sistema y esquema. En CPU, para un
modelo de 4B cuantizado a 4 bits, el *prefill* ronda las 60–150 tok/s y el *decode* las 8–12
tok/s. Es decir: ~10–25 s sólo en digerir la entrada, antes de emitir el primer token, y otros
~10 s de salida. Contra un `timeout_seconds: 30` eso no es un margen ajustado, es un timeout.

**Conclusión:** lo que hay que fijar no es "un modelo chico" sino un **presupuesto de tokens**.
Recortar la entrada de 1300 a ~450 tokens ahorra más latencia que cambiar de modelo, y no
degrada la clasificación: el nombre del archivo, la ruta, el tipo MIME y el primer párrafo son
casi toda la señal útil. Un documento no se vuelve más fácil de clasificar por leerle la
página 7.

## Alternativas consideradas

Familias efectivamente disponibles en la librería de Ollama al 2026-07-29, filtradas por
"corre en CPU con ≤ 6 GiB":

| Candidato | En disco | Licencia | Tools | Notas |
|---|---|---|---|---|
| **`qwen3.5:2b`** | ~2,7 GB | Apache 2.0 | ✅ | Familia de feb-2026. Multimodal (texto+imagen). 256K de contexto nativo. Hermanos de 0.8b a 122b: la familia entera cubre los dos niveles |
| **`qwen3.5:4b`** | ~3,4 GB | Apache 2.0 | ✅ | Igual, un escalón arriba. IFEval 89,8 — seguimiento de instrucciones muy bueno para 4B |
| `qwen3.5:9b` | ~6 GB | Apache 2.0 | ✅ | Mejor calidad de redacción; en CPU el *decode* baja a ~4–6 tok/s, o sea ~1–2 min por resumen |
| `granite4.1:3b` | ~2,1 GB | Apache 2.0 | ✅ | IBM, mayo-2026. Pensado para uso empresarial y *function calling*. Sin multimodalidad. Buen plan de escape si Qwen diera problemas |
| `gemma3:4b` | ~3,3 GB | Gemma Terms of Use | ✅ | Sólido, pero es de mediados de 2025 y la licencia no es OSI |
| `gemma4:12b` | ~8 GB | Gemma Terms of Use | ✅ | El Gemma actual arranca en 12B: no entra en el presupuesto de CPU |
| `qwen3:4b` | ~2,6 GB | Apache 2.0 | ✅ | Reemplazado por `qwen3.5:4b` dentro de la misma familia |
| `qwen2.5:3b` / `llama3.2:3b` | ~2 GB | — | parcial | **Los candidatos originales.** Descartados por antigüedad: dos generaciones atrás en seguimiento de instrucciones y en salida estructurada |

### Sobre el modo *thinking*

Qwen3.5 es una familia de razonamiento híbrido: **genera bloques `<think>` por defecto**. Para
clasificar es lo peor posible — multiplica los tokens de salida, que es la fase cara en CPU,
para una tarea que no necesita cadena de razonamiento. Ollama expone el interruptor como
parámetro `think` de la petición.

Que el modelo *pueda* razonar cuando se le pide es una ventaja para el nivel 2 (resúmenes) y
para el futuro agéntico. Que lo haga por defecto en la ruta de clasificación es un bug de
configuración esperando a ocurrir, y por eso queda fijado explícitamente más abajo.

## Decisión

**Familia: Qwen3.5. Dos niveles, con el presupuesto de tokens fijado por escrito.**

### Nivel 1 — clasificación (ruta síncrona del pipeline)

```yaml
model: qwen3.5:2b
```

| Parámetro | Valor | Por qué |
|---|---|---|
| `think` | `false` | La clasificación es una decisión, no un razonamiento. Ahorra el grueso de los tokens de salida |
| `format` | JSON Schema de `Classification` | Ollama acepta un esquema completo, no sólo `"json"`. Es la diferencia entre validar y rezar |
| `num_ctx` | `2048` | Techo del presupuesto de entrada, no una aspiración |
| `num_predict` | `128` | Un `Classification` no necesita más. Es el tope duro de la fase lenta |
| `keep_alive` | `5m` | Descarga el modelo de RAM tras inactividad (ADR-0001) |
| `max_content_chars` | **`1500`** (era 4000) | ~450 tokens. El hallazgo de arriba |

### Nivel 2 — generación (resúmenes e índices, ruta asíncrona)

```yaml
summary_model: qwen3.5:4b
```

Mismo modelo para los casos difíciles: cuando el nivel 1 devuelve confianza por debajo de
`min_confidence`, se reintenta con el 4b antes de caer al clasificador por reglas. Acá sí tiene
sentido permitir `think` y una salida más larga, porque nada bloquea al usuario.

`qwen3.5:9b` queda documentado como **opt-in** para la laptop i9/32 GiB si el benchmark muestra
margen: mejor redacción, pero uno a dos minutos por resumen en CPU.

### Modo degradado

En el plan B de Oracle Cloud A1 (4 OCPU ARM, [ADR-0003](0003-infraestructura-servidor.md)):
sólo nivel 1, y `qwen3.5:0.8b` si el 2b no llega. La generación de resúmenes se apaga por
configuración, no se recorta el diseño.

### Plan de escape

Si Qwen3.5 falla en salida estructurada de forma sistemática, el reemplazo es
**`granite4.1:3b`**: Apache 2.0, mismo orden de tamaño, *function calling* de primera clase.
El cambio es un valor en `archivista.yaml`, no un cambio de código — que es precisamente el
punto de que `classify/ai.py` sea una interfaz.

### Presupuesto de recursos resultante

| Componente | RAM |
|---|---|
| `qwen3.5:2b` cargado | ~2,5 GiB |
| `qwen3.5:4b` cargado (si conviven ambos) | ~3,5 GiB |
| `archivistad` | ≤ 200 MiB |
| Debian minimal | ~1 GiB |
| **Total** | **≈ 7,2 GiB de 32 GiB** |

Para evitar que los dos niveles coexistan en RAM sin control, la unidad de Ollama fija
`OLLAMA_MAX_LOADED_MODELS=1`: el nivel 2 desaloja al nivel 1, que se recarga solo en la
siguiente clasificación. Es un intercambio consciente de latencia por memoria acotada, y es
justamente el tipo de decisión de gestión de recursos que la materia pide mostrar.

## Consecuencias

### Positivas

- #17, #18 y #5 pueden arrancar hoy citando un nombre de modelo y un techo de tokens.
- El presupuesto de inferencia es explícito y **falsable**: #3 lo confirma o lo rompe con números.
- Los dos niveles son la misma familia y el mismo *tokenizer*: los prompts se escriben una vez.
- Qwen3.5 acepta imágenes. No entra en el alcance de la entrega, pero deja la puerta abierta a
  clasificar PDFs escaneados sin cambiar de familia de modelo.
- `tools` disponible en los dos niveles: cuando la capa de IA pase de etiquetar a proponer
  operaciones, no hay que volver a elegir modelo.

### Negativas / costos que aceptamos

- `max_content_chars: 1500` significa que un documento cuyo tema recién se revela en la mitad
  se clasifica peor. Lo aceptamos: para eso están el umbral de confianza, la escalada al 4b y
  el clasificador por reglas.
- `OLLAMA_MAX_LOADED_MODELS=1` hace que la primera clasificación después de un resumen pague la
  recarga del modelo (unos segundos de disco).
- Atarse a una familia concreta implica que en seis meses esta ADR va a estar vieja, igual que
  le pasó a la tabla que reemplaza. Es el costo normal de fijar una versión.

### Qué invalidaría esta decisión

Se hereda de ADR-0001 y se hace medible:

1. Que #3 mida **p95 > 15 s** por archivo en el nivel 1 con este presupuesto de tokens. En ese
   caso: bajar a `qwen3.5:0.8b` antes de tocar el diseño.
2. Que la tasa de JSON inválido supere el **2 %** con `format` + esquema. En ese caso: pasar a
   `granite4.1:3b`.
3. Que el clasificador por reglas de #13 gane en precisión al nivel 1 en el conjunto de prueba.
   En ese caso el problema no es el modelo sino la utilidad de la capa de IA, y hay que
   reabrir ADR-0001.

## Protocolo de validación (entrada para #3)

Para que el benchmark responda una pregunta cerrada y no sea "probar modelos":

**Corpus:** 30 archivos reales del disco de alguien del equipo, no sintéticos, con la mezcla
que va a ver el sistema: PDFs de apuntes, DOCX, imágenes, comprobantes, código, un par de
archivos deliberadamente ambiguos. Con su categoría correcta anotada a mano de antemano.

**Qué se mide, por cada uno de `qwen3.5:0.8b`, `qwen3.5:2b`, `qwen3.5:4b` y `granite4.1:3b`:**

| Métrica | Cómo |
|---|---|
| Latencia p50 / p95 / máxima | Reloj de pared de la llamada completa, 3 repeticiones |
| Prefill y decode por separado | `total_duration`, `prompt_eval_count`, `prompt_eval_duration`, `eval_count`, `eval_duration` — Ollama los devuelve en la respuesta |
| Tasa de JSON inválido | Validación contra el esquema de `Classification` |
| Exactitud | Contra las categorías anotadas a mano |
| RSS del proceso de Ollama | Con el modelo cargado y en uso |
| Efecto de `think` | El mismo corpus con `think: true` y `think: false` |
| Efecto del presupuesto de entrada | El mismo corpus con `max_content_chars` en 1500 y en 4000 |

**Umbrales de aceptación del nivel 1:** p95 ≤ 15 s · JSON inválido ≤ 2 % · exactitud ≥ 70 %
sobre los archivos no ambiguos.

El resultado se escribe en `docs/03-entorno-servidor.md` §3 reemplazando las estimaciones, y
si contradice esta ADR, se abre la ADR que la supersede. Una ADR que el benchmark refuta no se
edita: se marca como *Reemplazada*.
