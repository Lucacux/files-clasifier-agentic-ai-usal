# Architecture Decision Records (ADR)

Un ADR documenta **una decisión técnica y por qué se tomó**, incluyendo las alternativas que
se descartaron y qué se pierde con la elección.

Los escribimos porque el "por qué" de una decisión se evapora en dos semanas. Cuando alguien
del equipo —o el profesor— se pregunte "¿por qué usaron un modelo local en vez de la API de
OpenAI?", la respuesta tiene que estar escrita, no en la memoria de quien lo decidió.

## Índice

| # | Decisión | Estado |
|---|---|---|
| [0001](0001-ia-local-con-ollama.md) | Modelo de IA local con Ollama en lugar de API externa | Aceptada |
| [0002](0002-python-y-watchdog.md) | Python 3.11 + `watchdog` sobre inotify | Aceptada |
| [0003](0003-infraestructura-servidor.md) | Debian 12 minimal en hardware propio, cloud como plan B | Aceptada |
| [0004](0004-ipc-socket-unix.md) | Socket de dominio Unix para la comunicación CLI ↔ daemon | Aceptada |
| [0005](0005-borrado-con-aprobacion-humana.md) | Ninguna operación destructiva es automática | Aceptada |
| [0006](0006-idiomas-del-proyecto.md) | Documentación en español, código en inglés | Aceptada |
| [0007](0007-modelo-local-y-presupuesto-de-inferencia.md) | Qwen3.5 en dos niveles y presupuesto de inferencia explícito | Aceptada |

## Cuándo escribir uno

Si la decisión cumple **al menos dos** de estas condiciones, va ADR:

- Es difícil de revertir una vez implementada
- Afecta a más de un área del proyecto
- Hubo una alternativa razonable que se descartó
- Alguien va a preguntar "¿por qué así?" dentro de un mes

## Formato

Copiá [`_template.md`](_template.md), numerá secuencialmente y agregalo al índice de arriba
en el mismo Pull Request.

Un ADR aceptado **no se edita**: si la decisión cambia, se escribe uno nuevo que reemplace al
anterior y se marca el viejo como `Reemplazada por ADR-XXXX`. La historia de lo que pensamos
en cada momento es parte del valor.
