# 00 — Consigna original de la cátedra

> Transcripción literal de la consigna publicada en el aula virtual, conservada acá para que
> cualquiera pueda contrastar lo entregado contra lo pedido sin salir del repositorio.
>
> **Materia:** Sistemas Operativos — TM — Pilar — 2025
> **Profesor:** Josué Daniel Bohorquez Carrascal

---

## 🎓 Trabajo Práctico Final

### "Sistema Inteligente de Automatización con IA y Sistemas Operativos"

### 📌 Descripción general

El trabajo práctico final consiste en el desarrollo de un sistema que:

- Automatice tareas cotidianas relacionadas con el sistema operativo
- Utilice conceptos fundamentales de Sistemas Operativos
- Integre herramientas de Inteligencia Artificial
- Funcione de manera autónoma

El objetivo es construir una solución útil, automatizada y técnicamente fundamentada.

### 🎯 Objetivos

- Aplicar conceptos de Sistemas Operativos en un proyecto real
- Integrar Inteligencia Artificial en un flujo automatizado
- Diseñar soluciones que resuelvan problemas cotidianos
- Comprender la interacción entre software de bajo nivel y servicios inteligentes

### 💡 Idea base sugerida

Un ejemplo de proyecto es:

> Sistema inteligente que organiza archivos automáticamente utilizando eventos del sistema
> operativo e inteligencia artificial, adaptándose a perfiles de usuario como estudiante o
> profesor.

(Los grupos pueden proponer variantes siempre que cumplan los requisitos.)

---

### ⚙️ Requerimientos Funcionales

#### 1. Automatización

- El sistema debe ejecutarse automáticamente (sin intervención constante del usuario)
- Debe reaccionar ante eventos del sistema (ej: creación/modificación de archivos)

#### 2. Gestión de archivos

- Detectar archivos nuevos o modificados
- Clasificarlos según criterios definidos
- Moverlos o reorganizarlos en el sistema de archivos

#### 3. Integración de IA

El sistema debe utilizar IA para al menos una de las siguientes tareas:

- Clasificación de archivos por contenido
- Generación de resúmenes
- Generación de contenido (ej: notas, preguntas, planes)
- Toma de decisiones sobre organización

Ejemplo de uso: integración con APIs como OpenAI u otros modelos.

#### 4. Perfiles de usuario

El sistema debe permitir configurar al menos un perfil:

- 🎓 Estudiante
- 👨‍🏫 Profesor

Cada perfil debe modificar el comportamiento del sistema.

Ejemplo:

- Estudiante → generar resúmenes
- Profesor → organizar material de clase

#### 5. Generación de resultados

El sistema debe producir salidas útiles, por ejemplo:

- Archivos organizados en carpetas
- Archivos generados automáticamente (resúmenes, notas, etc.)
- Logs o notificaciones del sistema

---

### 🧱 Requerimientos Técnicos

#### 1. Uso de conceptos de Sistemas Operativos (OBLIGATORIO)

El proyecto debe incluir al menos 3 de los siguientes:

- Procesos y/o hilos
- Manejo del sistema de archivos
- Permisos de archivos
- Comunicación entre procesos (IPC)
- Automatización mediante eventos (ej: inotify)
- Scheduling o ejecución programada (cron, timers)
- Scripts de sistema (bash, shell)

#### 2. Ejecución como servicio

El sistema debe:

- Ejecutarse como proceso en background (daemon o servicio)
- Poder iniciarse/detenerse manualmente

#### 3. Manejo de concurrencia

El sistema debe ser capaz de:

- Procesar múltiples archivos
- Evitar bloqueos o errores por concurrencia

#### 4. Configuración

Debe existir un mecanismo de configuración, por ejemplo:

- Archivo `.json`, `.yaml` o `.env`
- CLI (línea de comandos)

Ejemplo:

```
modo=estudiante
carpeta_observada=/home/user/descargas
```

#### 5. Integración con IA

- Uso de APIs externas o modelos locales
- Manejo de requests/responses
- Tratamiento de errores (timeouts, fallos, etc.)

---

## Nuestra propuesta

Tomamos la idea base sugerida y la llevamos más lejos en dos direcciones:

1. **El modelo de IA corre localmente**, no contra una API externa. Esto obliga a
   administrar recursos del sistema de verdad (memoria, CPU, un servicio extra) en lugar de
   delegar en un tercero, y además ningún archivo del usuario sale de la máquina.
2. **Cubrimos los 7 conceptos de SO de la lista, no los 3 mínimos.** La trazabilidad de
   cuál concepto aparece en qué parte del código está en
   [`02-conceptos-so.md`](02-conceptos-so.md).

El mapeo punto por punto de la consigna contra la implementación está en
[`08-mapeo-requisitos.md`](08-mapeo-requisitos.md).
