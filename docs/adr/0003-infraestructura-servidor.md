# ADR-0003 — Debian 12 minimal en hardware propio, cloud como plan B

- **Estado:** Aceptada
- **Fecha:** 2026-07-29
- **Decide:** Luca Lombardo (PM)
- **Consultados:** todo el equipo

## Contexto

El sistema tiene que correr en algún lado, y ese lugar tiene que:

1. Poder cargar un modelo de IA local ([ADR-0001](0001-ia-local-con-ollama.md)) — entre 3 y 6
   GiB de RAM sólo para el modelo.
2. Ser accesible para los seis integrantes y para el profesor.
3. Ser un Linux donde tengamos `root`, porque necesitamos `systemd`, `sysctl`, usuarios,
   grupos y ACLs.
4. Estar disponible el día de la corrección.

Hardware disponible: una laptop con **i9 (≤ 3 años), 32 GiB DDR4, SSD NVMe**, sin GPU
dedicada asumida.

## Alternativas consideradas

### Opción A — Laptop con Debian 12 minimal (headless)

**Ventajas:** recursos de sobra; `root` completo; sin costo; permite usar el modelo de 7B para
generación de resúmenes, no sólo el de 3B; sin límites de free tier.

**Desventajas:** hay que tenerla encendida; el acceso remoto depende de la red doméstica
(NAT, IP dinámica); si se rompe, se rompe el entorno de todos.

### Opción B — Instancia cloud free tier

Analizamos qué free tier soporta realmente un modelo local:

| Proveedor | Free tier | RAM | ¿Sirve? |
|---|---|---|---|
| AWS EC2 | `t2.micro` / `t3.micro` | 1 GiB | ❌ No entra ni un 3B cuantizado |
| Google Cloud | `e2-micro` | 1 GiB | ❌ Igual |
| Azure | B1s (12 meses) | 1 GiB | ❌ Igual |
| Oracle Cloud | `VM.Standard.E2.1.Micro` (x86) | 1 GiB | ❌ Igual |
| **Oracle Cloud** | **`VM.Standard.A1.Flex` (ARM), siempre gratis** | **24 GiB / 4 OCPU** | ✅ **Única viable** |

El free tier de Oracle Ampere A1 es un caso atípico: 4 núcleos ARM y 24 GiB de RAM sin costo
permanente. Es el único que puede cargar el modelo.

**Ventajas:** disponible 24/7, IP pública fija, todos entran por SSH sin depender de la
laptop de nadie, el profesor accede desde cualquier lado.

**Desventajas:** es **ARM (aarch64)** — hay que verificar cada dependencia; 4 OCPU ARM rinden
bastante menos que un i9, lo que empujaría a usar sólo el modelo de 3B y aceptar latencias
mayores; y la disponibilidad de capacidad para crear instancias A1 es notoriamente
intermitente.

### Opción C — Máquina virtual local en la laptop de cada uno

Cada uno con su entorno. Descartada: seis entornos distintos garantizan seis versiones del
bug "en mi máquina anda", y no hay un lugar único donde el profesor pueda ver el sistema
funcionando.

## Decisión

**Servidor principal: Opción A — la laptop, con Debian 12 minimal headless.**
**Plan B evaluado en paralelo durante M0: Opción B — Oracle Cloud A1.**

Razones:

- El margen de recursos permite demostrar el sistema **completo**, incluyendo generación de
  resúmenes con el modelo de 7B. En Oracle A1 tendríamos que recortar esa parte.
- `root` completo sin restricciones de proveedor para todo lo que la materia pide: `sysctl`,
  cgroups, ACLs, unidades de systemd.
- Sin riesgo de que un free tier cambie de condiciones a mitad del cuatrimestre.

Sobre **headless y minimal**: sin entorno de escritorio no hay indexadores ni sincronizadores
generando eventos de filesystem que no son del usuario, lo que sería ruido directo sobre el
mecanismo que estamos demostrando. Y funcionar sin GUI prueba que es un servicio de verdad.
El sistema se traslada sin cambios a una máquina con escritorio: lo único que se activa de
más son las notificaciones, detrás de un flag de configuración.

El plan B **no es teórico**: es un issue asignado en M0. Si Oracle A1 funciona, queda como
entorno secundario permanentemente encendido, lo que resuelve el peor riesgo de la Opción A
(que el día de la corrección la laptop esté apagada o sin red).

## Consecuencias

### Positivas

- Recursos de sobra: modelo grande disponible, sin recortar funcionalidad.
- Control total del sistema operativo.
- Sin costos ni límites de proveedor.
- x86-64: sin sorpresas de compatibilidad de dependencias.

### Negativas / costos que aceptamos

- Disponibilidad atada a que la laptop esté encendida y con red.
- El acceso remoto necesita solución (túnel o VPN); es un issue de M0.
- Punto único de falla mientras el plan B no esté validado.

### Qué invalidaría esta decisión

- Que el acceso remoto a la laptop resulte impracticable y Oracle A1 sí funcione: en ese caso
  se invierte, A1 pasa a principal y aceptamos correr sólo el modelo de 3B.
- Que aparezca hardware dedicado mejor (un mini-PC, un servidor de la facultad).
