# 04 — Runbook: provisionar el servidor

Guía operativa del [issue #1](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues/1).
**Responsable: Luca Lombardo.** El entorno de destino está descrito en
[`03-entorno-servidor.md`](03-entorno-servidor.md) y la justificación en
[ADR-0003](adr/0003-infraestructura-servidor.md).

## Qué automatiza el script y qué no

`scripts/bootstrap-server.sh` hace lo repetible: paquetes, `sysctl` de inotify, cuentas del
equipo con su clave, endurecimiento de `sshd`, `ufw` y —si el servidor es una laptop— que
cerrar la tapa no la suspenda.

Lo que **no** hace, porque requiere una persona frente a la máquina o una decisión que el
script no puede tomar:

| Fuera del script | Por qué |
|---|---|
| Instalar Debian | Hay que arrancar de un pendrive y elegir el particionado |
| BIOS/UEFI | No se toca desde el sistema operativo |
| Elegir cómo se entra desde afuera | Depende de si el ISP da IP pública o hace CGNAT, y de qué querés mantener |
| Confirmar que SSH sigue funcionando | La única prueba válida es entrar desde otra máquina |

El script **no modifica nada** hasta que le pasás `--apply`. Corrélo sin ese flag primero y leé
la salida: eso es parte del procedimiento, no una precaución opcional.

---

## Decisiones previas (son tuyas, no del script)

Anotá las respuestas en el issue #1 antes de arrancar. Si más adelante algo se rompe, el
diagnóstico empieza por acá.

1. **Qué máquina.** ADR-0003 asume la laptop i9 con 32 GiB. Si cambia el hardware, la ADR y
   el presupuesto de recursos de ADR-0007 cambian con ella.
2. **Nombre de host.** El que uses queda en los logs y en la documentación de entrega.
3. **Particionado.** Un `/` grande alcanza. Si separás `/var`, dale espacio de sobra: ahí van
   los logs de auditoría, la caché de inferencias y los modelos de Ollama (varios GB).
4. **Quién administra.** Todos los integrantes entran con `sudo` (así está el issue #2), pero
   decidí si `demo` y `profesor` se crean ahora o en #2. Recomendación: en #2, para no mezclar.
5. **Cómo se entra desde afuera.** La decisión con más consecuencias. Ver más abajo.

---

## Paso 0 — Instalar Debian 12 minimal

Imagen `netinst` de amd64. En `tasksel`, la pantalla de selección de software:

- **Desmarcá** «Debian desktop environment» y todos los entornos gráficos.
- **Dejá marcado** «SSH server» y «standard system utilities».

Sin entorno gráfico no hay indexadores ni *thumbnailers* generando eventos de filesystem que
no son del usuario, que es exactamente el ruido que arruinaría una demo del watcher.

Al terminar, verificá que arranca en consola de texto y que `ip -brief address` te muestra una
dirección de la LAN.

## Paso 1 — BIOS/UEFI (sólo si el servidor es una laptop)

Con la máquina apagada, entrá al BIOS y dejá:

- **Suspensión al cerrar la tapa:** desactivada, si el BIOS lo expone.
- **«Restore on AC power loss» / «Power on after power failure»:** activado. Sin esto, un corte
  de luz deja el servidor apagado hasta que alguien vaya a apretar el botón.
- **Wake-on-LAN:** activado si lo vas a usar; no es necesario para el proyecto.

El paso `logind` del script cubre la parte del sistema operativo (`HandleLidSwitch=ignore`),
pero si el firmware suspende por hardware, el sistema operativo no llega a opinar.

## Paso 2 — Juntar las claves públicas del equipo

Cada integrante abre un PR agregando su clave en `deploy/team-keys/<usuario>.pub`. El
procedimiento está en [`deploy/team-keys/README.md`](../deploy/team-keys/README.md).

**No arranques el paso `ssh-hardening` hasta que tu propia clave esté autorizada y probada.**
El script se niega a apagar la autenticación por contraseña si ningún usuario con `sudo` tiene
`authorized_keys`, pero esa comprobación no puede saber si *tu* clave es la correcta.

## Paso 3 — Dry-run

```bash
git clone git@github.com:Lucacux/files-clasifier-agentic-ai-usal.git
cd files-clasifier-agentic-ai-usal
sudo ./scripts/bootstrap-server.sh          # no modifica nada
```

Leé la salida completa. El paso `inventory` imprime `lscpu`, `free -h`, `df -hT` y el tipo de
chasis: **eso es lo que hay que pegar en el issue #1**, porque son los números que justifican
las decisiones de recursos de la documentación.

## Paso 4 — Aplicar, por pasos y con una segunda terminal abierta

Antes de tocar SSH, abrí **otra** terminal con una sesión ya establecida al servidor y no la
cierres. Si algo sale mal, esa sesión es la diferencia entre arreglarlo en 30 segundos y bajar
a buscar un teclado y un monitor.

```bash
sudo ./scripts/bootstrap-server.sh --only inventory --only packages --apply
sudo ./scripts/bootstrap-server.sh --only sysctl --only logind --apply
sudo ./scripts/bootstrap-server.sh --only team-keys --apply

# Ahora, desde OTRA máquina, comprobá que entrás con clave:
#   ssh -o PasswordAuthentication=no luca@<ip-del-servidor>
# Sólo si eso funciona:
sudo ./scripts/bootstrap-server.sh --only ssh-hardening --apply
sudo ./scripts/bootstrap-server.sh --only firewall --apply
```

Correr todo de una sola vez con `--apply` también funciona y es idempotente, pero la secuencia
de arriba te deja un punto de control antes del único paso que puede dejarte afuera.

### Si te quedás afuera

El firewall y `sshd` se configuran con archivos *drop-in* precisamente para esto: desde la
consola física, `rm /etc/ssh/sshd_config.d/60-archivista.conf && systemctl restart ssh` te
devuelve el estado anterior. Para el firewall, `ufw disable`.

## Paso 5 — Acceso remoto (decisión, no comando)

```bash
sudo ./scripts/bootstrap-server.sh --only remote-access
```

Ese paso sólo diagnostica: muestra la IP pública vista desde afuera y los primeros saltos de
red. **Si en el segundo salto aparece una dirección `100.64.x.x`–`100.127.x.x`, el ISP hace
CGNAT** y no vas a poder abrir puertos, por más que configures el router.

| Opción | Cuándo | Costo |
|---|---|---|
| Túnel (Cloudflare Tunnel o Tailscale) | Siempre funciona, también con CGNAT | Una dependencia externa más en la demo |
| Redirección de puerto + DNS dinámico | Sólo con IP pública real | Expone SSH a internet: `fail2ban` pasa a ser obligatorio |
| Sólo LAN | Si nada de lo anterior es viable | El plan B de cloud ([#4](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues/4)) sube de prioridad, porque el profesor tiene que poder entrar |

Cualquiera que elijas, anotá en el issue #1 **cuál** y **por qué**: el informe final lo pide.

## Paso 6 — Verificar y cerrar el issue

```bash
sudo ./scripts/bootstrap-server.sh --only verify
```

Devuelve código de salida distinto de cero si algo no cumple. Cierra el issue #1 cuando:

- `verify` no reporta ninguna falla.
- Los seis integrantes confirmaron que entran por SSH con su clave.
- La salida de `inventory` y la decisión de acceso remoto están pegadas en el issue.
- `docs/03-entorno-servidor.md` §7 tiene los comandos **realmente** ejecutados, no los
  previstos. Si el script necesitó ajustes en la máquina real, esos ajustes van al script en
  el mismo PR.

---

## Lo que sigue, y de quién es

| Issue | Qué falta | Dueño |
|---|---|---|
| [#2](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues/2) | Usuarios `archivista`, `demo` y `profesor`; grupos y ACLs | Luca |
| [#3](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues/3) | Instalar Ollama, bajar el modelo y medir latencia | Emma |
| [#27](https://github.com/Lucacux/files-clasifier-agentic-ai-usal/issues/27) | Unidades de systemd, timer y logrotate | Luca |

Ollama **no** se instala en este issue. Se instala en #3, escucha sólo en `127.0.0.1` y no se
abre ningún puerto en el firewall para él.
