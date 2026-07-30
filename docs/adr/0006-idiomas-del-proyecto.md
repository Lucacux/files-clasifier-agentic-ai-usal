# ADR-0006 — Documentación en español, código en inglés

- **Estado:** Aceptada
- **Fecha:** 2026-07-29
- **Decide:** Luca Lombardo (PM)
- **Consultados:** todo el equipo

## Contexto

Todo el equipo y el profesor son hispanohablantes. El repositorio es público. Hay que fijar
una convención antes de que aparezcan tres estilos distintos mezclados en el mismo archivo,
que es lo que pasa siempre cuando no se decide.

## Alternativas consideradas

### Opción A — Todo en español

Coherente y máximamente accesible para la cátedra. Pero el código en español choca con
absolutamente todo: las bibliotecas, la biblioteca estándar, los mensajes de error, los
ejemplos que vamos a buscar. Termina en híbridos como `def mover_file(ruta_source)`, que es lo
peor de los dos mundos.

### Opción B — Todo en inglés

Es el estándar de la industria y lo que haríamos en un proyecto profesional. Pero la
documentación es lo que **evalúa el profesor**, y escribirla en un idioma que no es el nuestro
sólo agrega ruido y errores de expresión sin beneficio alguno para el lector real.

### Opción C — Separación por audiencia

Cada artefacto en el idioma de quien lo va a leer.

## Decisión

**Opción C.** El criterio es simple: *¿quién lee esto?*

| Artefacto | Idioma | Lo lee |
|---|---|---|
| `docs/`, `README.md`, ADRs | 🇪🇸 Español | El profesor y el equipo |
| Issues, Pull Requests, comentarios de revisión | 🇪🇸 Español | El equipo (y el profesor, como evidencia del proceso) |
| Nombres de variables, funciones, clases, módulos | 🇬🇧 Inglés | Quien programa, junto al resto del ecosistema |
| Docstrings y comentarios de código | 🇬🇧 Inglés | Idem — quedan pegados al código |
| Mensajes de commit | 🇬🇧 Inglés | Conventional Commits, tooling estándar |
| Mensajes del CLI y logs para el usuario | 🇪🇸 Español | El usuario final del sistema |
| Nombres de carpetas destino generadas | 🇪🇸 Español | El usuario en su propio filesystem |

Ejemplo de la separación en la práctica:

```python
def move_to_category(source: Path, category: str) -> Path:
    """Move a file to its category folder, preserving permissions.

    Raises:
        PathOutsideSandboxError: if the resolved destination escapes the
            configured whitelist.
    """
    ...
    logger.info("Archivo movido a %s", destination)  # lo lee el usuario
```

## Consecuencias

### Positivas

- El profesor lee toda la documentación en su idioma, sin fricción.
- El código se ve como código profesional y encaja con el ecosistema.
- La regla es fácil de aplicar y de revisar: si lo lee una persona ajena al código, español;
  si vive dentro del código, inglés.

### Negativas / costos que aceptamos

- Hay que cambiar de idioma al pasar de escribir código a escribir el issue. Es un costo
  cognitivo chico y real.
- Los mensajes de log tienen texto en español dentro de archivos en inglés. Es intencional:
  ese texto es interfaz de usuario, no código.

### Qué invalidaría esta decisión

Que el proyecto se abriera a colaboradores no hispanohablantes. En ese caso la documentación
pasaría a inglés, o se mantendría en ambos idiomas.
