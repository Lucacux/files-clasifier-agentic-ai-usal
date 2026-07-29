# Guía de contribución

Este documento define **cómo trabajamos**. No es burocracia: es lo que hace que seis
personas puedan tocar el mismo repo sin romperse cosas, y que el profesor pueda leer la
historia del proyecto y entender qué hicimos y por qué.

Si venís de fuera del equipo: todo lo que está acá se aplica igual.

---

## 1. Idiomas del proyecto

Decisión tomada en [ADR-0006](docs/adr/0006-idiomas-del-proyecto.md):

| Qué | Idioma |
|---|---|
| Documentación (`docs/`, `README.md`) | 🇪🇸 Español |
| Issues, PRs y discusiones | 🇪🇸 Español |
| Código: nombres, docstrings, comentarios | 🇬🇧 Inglés |
| Mensajes de commit | 🇬🇧 Inglés (Conventional Commits) |
| Mensajes que ve el usuario final (CLI, logs) | 🇪🇸 Español |

---

## 2. Flujo de trabajo con Git

Usamos **trunk-based development con ramas de feature cortas**. No hay `develop`.

```
main ──●──────●──────●──────●──────>   (siempre desplegable, protegida)
        \    /        \    /
         ●──●          ●──●            ramas de feature (vida corta: 1-3 días)
```

### 2.1 Regla de oro

> **Nadie hace push directo a `main`.** Todo entra por Pull Request con al menos 1 aprobación.

### 2.2 Nombres de rama

```
<tipo>/<nº-issue>-<descripción-corta-en-kebab-case>
```

| Tipo | Cuándo |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de bug |
| `docs` | Solo documentación |
| `chore` | Tooling, dependencias, CI |
| `refactor` | Cambio interno sin cambiar comportamiento |
| `test` | Solo tests |

Ejemplos:

```
feat/12-clasificador-por-reglas
fix/28-race-condition-en-cola
docs/30-guia-instalacion
```

### 2.3 Ciclo completo

```bash
# 1. Partir siempre de main actualizada
git checkout main
git pull origin main

# 2. Crear la rama a partir del issue que te asignaron
git checkout -b feat/12-clasificador-por-reglas

# 3. Trabajar y commitear en pasos chicos
git add -p
git commit -m "feat(classifier): add MIME-based rule matching"

# 4. Antes de abrir el PR, sincronizar con main
git fetch origin
git rebase origin/main        # resolver conflictos acá, no en el PR

# 5. Correr las validaciones locales (lo mismo que corre el CI)
make check

# 6. Push y abrir PR
git push -u origin feat/12-clasificador-por-reglas
```

---

## 3. Mensajes de commit — Conventional Commits

Formato obligatorio:

```
<tipo>(<ámbito>): <descripción en imperativo, minúscula, sin punto final>

[cuerpo opcional: el POR QUÉ, no el QUÉ — el qué está en el diff]

[Refs: #12]
```

Tipos válidos: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `ci`, `build`.

Ámbitos habituales: `watcher`, `classifier`, `ai`, `profiles`, `daemon`, `ipc`, `cli`,
`config`, `logging`, `infra`, `docs`.

✅ Bien:

```
feat(watcher): debounce inotify events until file size is stable

Los navegadores escriben el archivo en varios chunks, así que IN_MODIFY
se dispara múltiples veces sobre un archivo incompleto. Esperamos a que
el tamaño no cambie durante `stability_window` antes de encolar.

Refs: #9
```

❌ Mal: `cambios`, `fix`, `update stuff`, `WIP`, `asdasd`.

---

## 4. Pull Requests

### 4.1 Requisitos para poder mergear

- [ ] El PR está enlazado a un issue (`Closes #12`)
- [ ] El CI está en verde (lint + tipos + tests)
- [ ] Al menos **1 aprobación** de otra persona del equipo
- [ ] Sin conflictos con `main`
- [ ] La documentación afectada fue actualizada en el mismo PR
- [ ] Los tests nuevos cubren el camino feliz **y** al menos un caso de error

### 4.2 Tamaño

Apuntá a PRs de **menos de 400 líneas** de diff. Si tu issue da para más, partilo en varios
PRs incrementales. Un PR gigante no se revisa: se aprueba a ciegas, que es peor que no
revisarlo.

### 4.3 Estrategia de merge

**Squash and merge**, siempre. El título del squash debe ser un Conventional Commit válido,
porque es lo que queda en la historia de `main`.

### 4.4 Cómo revisar

Revisar no es buscar errores de tipeo. Preguntate:

1. ¿Hace lo que dice el issue?
2. ¿Qué pasa si el archivo desaparece a mitad de la operación? ¿Y si Ollama tarda 40 s?
3. ¿Esto rompe algo de otro módulo?
4. ¿Lo entendería alguien del equipo que no escribió esto?

Usá los prefijos convencionales al comentar para que se entienda qué bloquea y qué no:

- `blocking:` hay que arreglarlo antes de mergear
- `suggestion:` mejora opcional
- `question:` no entiendo, explicame
- `nit:` cosmético, no bloquea

---

## 5. Issues

- Cada issue tiene **un responsable** y **un milestone**.
- Si un issue te lleva más de 3 días, avisá en el issue: probablemente haya que partirlo.
- Si te bloqueás, comentá en el issue con la etiqueta `blocked` **el mismo día**. No esperes
  a la reunión.
- Antes de empezar, comentá `Tomando este issue` y asignátelo.

### Etiquetas

| Etiqueta | Significado |
|---|---|
| `area:infra` | Servidor, systemd, permisos, despliegue |
| `area:watcher` | inotify, eventos, concurrencia |
| `area:ai` | Ollama, prompts, extracción de contenido |
| `area:profiles` | Perfiles de usuario y configuración |
| `area:cli` | Daemon, IPC, línea de comandos |
| `area:observability` | Logs, auditoría, notificaciones |
| `area:docs` | Documentación |
| `area:ci` | Integración continua y tooling |
| `type:feature` / `type:bug` / `type:chore` / `type:docs` | Tipo de trabajo |
| `prio:alta` / `prio:media` / `prio:baja` | Prioridad |
| `blocked` | Bloqueado por algo externo |
| `good-first-task` | Buen punto de entrada |

---

## 6. Calidad de código

Todo lo que corre en CI se puede correr en local:

```bash
make fmt      # formatear (ruff format)
make lint     # linter (ruff check)
make types    # chequeo de tipos (mypy)
make test     # tests (pytest)
make check    # todo lo anterior — lo mismo que el CI
```

Instalá los hooks de pre-commit una sola vez y te olvidás:

```bash
pre-commit install
```

### Reglas no negociables

1. **Ninguna operación destructiva sin aprobación explícita del usuario.** Ver
   [ADR-0005](docs/adr/0005-borrado-con-aprobacion-humana.md).
2. **Ninguna ruta se toca sin validar contra la whitelist** de rutas permitidas.
   Nada de `../..`, nada de seguir symlinks fuera del sandbox.
3. **Ningún secreto en el repo.** Ni tokens, ni contraseñas, ni rutas personales
   con datos sensibles. Va todo por `.env` (que está en `.gitignore`).
4. **Toda operación sobre el filesystem se registra** en el log de auditoría.
5. **Toda llamada a la IA tiene timeout y fallback.** Si el modelo no responde, el sistema
   degrada al clasificador por reglas; nunca se cuelga ni pierde el archivo.

---

## 7. Definición de "terminado"

Un issue se cierra cuando:

- [ ] El código está en `main` vía PR aprobado
- [ ] Tiene tests que pasan en CI
- [ ] La documentación relevante está actualizada
- [ ] Si aplica: funciona en el servidor de verdad, no solo en la laptop de quien lo escribió
- [ ] Si tomó una decisión de arquitectura no trivial: hay un ADR en `docs/adr/`

---

## 8. Ritmo de trabajo

| Cuándo | Qué |
|---|---|
| Cada lunes | Revisión del tablero: qué se movió, qué está bloqueado |
| Al terminar un milestone | Demo interna de 15 min + retro corta |
| Siempre | Si algo te bloquea, se dice el mismo día en el issue |
