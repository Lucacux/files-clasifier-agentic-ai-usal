# ADR-0001 — Modelo de IA local con Ollama en lugar de API externa

- **Estado:** Aceptada
- **Fecha:** 2026-07-29
- **Decide:** Luca Lombardo (PM)
- **Consultados:** Emma Tamborini, todo el equipo

## Contexto

La consigna admite explícitamente ambas vías: *"Uso de APIs externas o modelos locales"*, y
menciona OpenAI como ejemplo. Hay que elegir una.

Restricciones reales:

- El sistema lee **el contenido de los archivos personales del usuario** para clasificarlos.
- El hardware disponible es una laptop con i9 y 32 GiB de RAM, **sin GPU dedicada asumida**.
- Es un trabajo universitario: no hay presupuesto para créditos de API, y una clave de API
  compartida entre seis personas en un repositorio público es un problema de seguridad
  esperando a ocurrir.
- El sistema tiene que poder demostrarse funcionando el día de la corrección, sin depender de
  que haya internet en el aula ni de que una clave siga vigente.

## Alternativas consideradas

### Opción A — API externa (OpenAI, Anthropic, Google)

**Ventajas:** modelos muy superiores, latencia baja, cero consumo de recursos locales,
integración trivial.

**Desventajas:**

- Cada archivo del usuario se envía a un tercero. Para un sistema cuyo propósito es ordenar
  documentos personales, es difícil de justificar.
- Requiere una clave de API en un repo público. Se puede manejar con variables de entorno,
  pero es una fuente de fallo y de fuga.
- Requiere conexión a internet durante la demo.
- Costo por archivo procesado, con un free tier que se agota.
- **Desde el punto de vista de la materia, es la opción menos interesante:** delegar la
  inferencia en un servicio externo no ejercita ningún concepto de Sistemas Operativos.

### Opción B — Modelo local con Ollama

**Ventajas:**

- Ningún archivo sale de la máquina.
- Sin claves, sin costos, sin dependencia de internet.
- **Obliga a administrar recursos del sistema de verdad:** un servicio extra con su propia
  unidad de systemd, límites de memoria y CPU con cgroups, gestión del ciclo de vida del
  modelo en RAM. Eso *es* materia de Sistemas Operativos.
- Ollama expone una API HTTP estable y se gestiona como cualquier otro servicio del sistema.

**Desventajas:**

- Modelos sensiblemente más débiles que los de frontera.
- Latencia mucho mayor en CPU (segundos, no milisegundos).
- Consumo de RAM permanente mientras el modelo está cargado.
- Salida menos confiable: más riesgo de JSON inválido o categorías inventadas.

### Opción C — Modelo local con llama.cpp directamente

Más control y algo menos de overhead, pero hay que gestionar la carga del modelo, el
servidor HTTP y la compilación a mano. Ollama resuelve todo eso y en la práctica es
`llama.cpp` por debajo. No justifica el trabajo extra para este proyecto.

## Decisión

**Opción B: modelo local vía Ollama.**

El argumento decisivo no es técnico sino de propósito: en un trabajo de Sistemas Operativos,
correr el modelo localmente **agrega** contenido de la materia (gestión de servicios, cgroups,
IPC sobre loopback, administración de memoria) mientras que llamar a una API externa lo
**quita**. Que además evite mandar los archivos del usuario a un tercero y no dependa de
internet durante la demo, lo confirma.

Las debilidades del modelo local se compensan por diseño:

| Debilidad | Compensación |
|---|---|
| Modelo más débil | La clasificación es una tarea de decisión corta, no de razonamiento profundo. Un 3B alcanza. |
| Latencia alta | El procesamiento es asíncrono: al usuario no lo bloquea nada. |
| Salida poco confiable | Validación de esquema JSON + umbral de confianza + fallback a reglas. |
| Consumo de RAM | `keep_alive` descarga el modelo tras inactividad; `MemoryMax` en la unidad de systemd. |

## Consecuencias

### Positivas

- Privacidad por diseño: es un argumento fuerte y verificable del proyecto.
- La demo funciona sin internet.
- Se suma un concepto de SO que con una API externa no existiría.
- Sin secretos en el repositorio.

### Negativas / costos que aceptamos

- El servidor necesita como mínimo 8 GiB de RAM libres, lo que **descarta casi todos los free
  tier de cloud** (ver [ADR-0003](0003-infraestructura-servidor.md)).
- La calidad de clasificación va a ser menor que con un modelo de frontera. Lo asumimos.
- Hay que medir la latencia real en el hardware antes de comprometer el diseño: es un issue
  bloqueante del milestone M0.

### Qué invalidaría esta decisión

- Que el benchmark de M0 muestre latencias inaceptables (> 30 s por archivo) incluso con el
  modelo de 3B.
- Que la calidad de clasificación sea tan mala que el clasificador por reglas gane siempre —
  en cuyo caso la capa de IA no estaría aportando nada.

En cualquiera de esos casos, el plan de contingencia es agregar un *backend* de API externa
**opcional y desactivado por defecto**, detrás de la misma interfaz del cliente de IA. La
arquitectura ya lo permite: `classify/ai.py` es una interfaz, no una implementación.
