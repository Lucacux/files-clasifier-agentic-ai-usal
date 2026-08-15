#!/usr/bin/env bash
#
# bootstrap-server.sh — deja un Debian 12 minimal listo para archivista.
#
# Idempotente: correrlo dos veces no cambia nada la segunda vez.
# Por defecto NO modifica nada: hay que pasar --apply explícitamente.
#
# El runbook con los pasos manuales que este script NO hace (instalación del
# sistema, BIOS, acceso remoto) está en docs/10-runbook-servidor.md.
#
# Uso:
#   sudo ./scripts/bootstrap-server.sh                    # dry-run de todo
#   sudo ./scripts/bootstrap-server.sh --apply            # aplica todo
#   sudo ./scripts/bootstrap-server.sh --only sysctl --apply
#   ./scripts/bootstrap-server.sh --list-steps
#
set -Eeuo pipefail

readonly SCRIPT_NAME=${0##*/}
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_ROOT
readonly SYSCTL_FILE=/etc/sysctl.d/60-archivista.conf
readonly SSHD_DROPIN=/etc/ssh/sshd_config.d/60-archivista.conf
readonly LOGIND_DROPIN=/etc/systemd/logind.conf.d/60-archivista.conf

readonly ALL_STEPS=(inventory packages sysctl logind team-keys ssh-hardening firewall remote-access verify)

readonly BASE_PACKAGES=(
  acl
  curl
  git
  jq
  libmagic1
  logrotate
  python3
  python3-venv
  socat
  ufw
)

APPLY=false
KEYS_DIR="$REPO_ROOT/deploy/team-keys"
STEPS=("${ALL_STEPS[@]}")
FAILED_CHECKS=0

# --------------------------------------------------------------------------
# Salida
# --------------------------------------------------------------------------

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

log()   { printf '%s\n' "$*"; }
title() { printf '\n%s== %s ==%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"; }
ok()    { printf '  %sOK%s    %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '  %saviso%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fail()  { printf '  %sFALLA%s %s\n' "$C_RED" "$C_RESET" "$*"; FAILED_CHECKS=$((FAILED_CHECKS + 1)); }
die()   { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
todo()  { printf '  %shaz esto vos%s %s\n' "$C_YELLOW$C_BOLD" "$C_RESET" "$*"; }

# Ejecuta un comando, o lo muestra si estamos en dry-run.
run() {
  if [[ $APPLY == true ]]; then
    log "  + $*"
    "$@"
  else
    log "  ${C_YELLOW}[dry-run]${C_RESET} $*"
  fi
}

# Escribe un archivo sólo si su contenido cambia. Lee el contenido de stdin.
write_file() {
  local path=$1 mode=${2:-0644} content
  content=$(cat)

  if [[ -f $path ]] && [[ $(cat -- "$path") == "$content" ]]; then
    ok "$path ya tiene el contenido esperado"
    return 0
  fi

  if [[ $APPLY == true ]]; then
    log "  + escribiendo $path"
    install -d -m 0755 -- "$(dirname -- "$path")"
    printf '%s\n' "$content" >"$path"
    chmod -- "$mode" "$path"
  else
    log "  ${C_YELLOW}[dry-run]${C_RESET} escribiría $path (modo $mode):"
    printf '%s\n' "$content" | sed 's/^/      | /'
  fi
}

# --------------------------------------------------------------------------
# Pasos
# --------------------------------------------------------------------------

# Sólo lee. Su salida es lo que hay que pegar en el issue #1.
step_inventory() {
  title "Inventario del hardware (pegá esto en el issue #1)"
  log "  ── uname ──";   uname -a | sed 's/^/  /'
  log "  ── os ──";      sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"' | sed 's/^/  /'
  log "  ── lscpu ──";   lscpu | grep -E '^(Model name|Architecture|CPU\(s\)|Thread|Core)' | sed 's/^/  /'
  log "  ── memoria ──"; free -h | sed 's/^/  /'
  log "  ── discos ──";  df -hT -x tmpfs -x devtmpfs | sed 's/^/  /'
  log "  ── red ──";     ip -brief address | sed 's/^/  /'

  local chassis=desconocido
  [[ -r /sys/class/dmi/id/chassis_type ]] && chassis=$(cat /sys/class/dmi/id/chassis_type)
  log "  ── chasis ──"
  log "  chassis_type=$chassis $(is_laptop && echo '(laptop: se configura logind)' || echo '(no laptop)')"
}

is_laptop() {
  local t
  [[ -r /sys/class/dmi/id/chassis_type ]] || return 1
  t=$(cat /sys/class/dmi/id/chassis_type)
  [[ $t == 8 || $t == 9 || $t == 10 || $t == 11 || $t == 14 || $t == 31 ]]
}

step_packages() {
  title "Paquetes base"
  local missing=()
  local pkg
  for pkg in "${BASE_PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'ok installed'; then
      continue
    fi
    missing+=("$pkg")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "los ${#BASE_PACKAGES[@]} paquetes base ya están instalados"
    return 0
  fi

  log "  faltan: ${missing[*]}"
  run apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends "${missing[@]}"
}

step_sysctl() {
  title "Parámetros de inotify"
  write_file "$SYSCTL_FILE" 0644 <<'EOF'
# Gestionado por scripts/bootstrap-server.sh — ver docs/03-entorno-servidor.md
# Por defecto max_user_watches son 8192: insuficiente para árboles grandes.
fs.inotify.max_user_watches   = 524288
fs.inotify.max_user_instances = 512
# Reduce IN_Q_OVERFLOW en ráfagas de eventos (descompresión de un zip grande).
fs.inotify.max_queued_events  = 32768
EOF
  run sysctl --quiet --load="$SYSCTL_FILE"
}

# El servidor es una laptop: si se cierra la tapa, se suspende y el daemon deja
# de existir para la red. Esto no es opcional en este proyecto.
step_logind() {
  title "Tapa y botón de encendido (laptop como servidor)"
  if ! is_laptop; then
    ok "el chasis no es una laptop: no hace falta tocar logind"
    return 0
  fi

  write_file "$LOGIND_DROPIN" 0644 <<'EOF'
# Gestionado por scripts/bootstrap-server.sh
# La laptop es un servidor headless: cerrar la tapa no puede suspenderla,
# y el botón de encendido no puede apagarla por un roce.
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
HandleLidSwitchExternalPower=ignore
HandlePowerKey=ignore
EOF
  run systemctl restart systemd-logind
  todo "confirmá en el BIOS: sin suspensión por tapa y «restore on AC power loss» activado"
}

# Crea las cuentas de los integrantes a partir de sus claves públicas.
# El nombre de usuario sale del nombre del archivo: luca.pub -> usuario luca.
step_team_keys() {
  title "Cuentas del equipo y claves SSH"

  if [[ ! -d $KEYS_DIR ]]; then
    fail "no existe $KEYS_DIR"
    todo "creá el directorio y poné ahí una clave pública por integrante (luca.pub, emma.pub, ...)"
    todo "pedíselas con: ssh-keygen -t ed25519 -C tu-nombre && cat ~/.ssh/id_ed25519.pub"
    return 1
  fi

  local keys=("$KEYS_DIR"/*.pub)
  if [[ ! -e ${keys[0]} ]]; then
    fail "$KEYS_DIR no tiene ningún archivo .pub"
    return 1
  fi

  local key user home_dir
  for key in "${keys[@]}"; do
    user=$(basename -- "$key" .pub)

    if ! ssh-keygen -l -f "$key" >/dev/null 2>&1; then
      fail "$key no es una clave pública SSH válida"
      continue
    fi

    if id -u "$user" >/dev/null 2>&1; then
      ok "el usuario $user ya existe"
    else
      run adduser --disabled-password --gecos "" "$user"
    fi
    run usermod --append --groups sudo "$user"

    home_dir=$(getent passwd "$user" | cut -d: -f6)
    home_dir=${home_dir:-/home/$user}

    if [[ $APPLY == true ]]; then
      install -d -m 0700 -o "$user" -g "$user" -- "$home_dir/.ssh"
      touch -- "$home_dir/.ssh/authorized_keys"
      # Idempotente: la clave se agrega sólo si no está ya.
      if grep -qxFf "$key" "$home_dir/.ssh/authorized_keys" 2>/dev/null; then
        ok "la clave de $user ya estaba autorizada"
      else
        cat -- "$key" >>"$home_dir/.ssh/authorized_keys"
        log "  + clave de $user agregada"
      fi
      chown -- "$user:$user" "$home_dir/.ssh/authorized_keys"
      chmod 0600 -- "$home_dir/.ssh/authorized_keys"
    else
      log "  ${C_YELLOW}[dry-run]${C_RESET} autorizaría $(basename -- "$key") en $home_dir/.ssh/authorized_keys"
    fi
  done
}

# Cuenta cuántos usuarios con sudo tienen al menos una clave autorizada.
# Es la red de seguridad antes de apagar la autenticación por contraseña.
count_sudo_users_with_keys() {
  local total=0 user home_dir
  while IFS= read -r user; do
    home_dir=$(getent passwd "$user" | cut -d: -f6)
    [[ -n $home_dir && -s $home_dir/.ssh/authorized_keys ]] && total=$((total + 1))
  done < <(getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -v '^$')
  printf '%s\n' "$total"
}

step_ssh_hardening() {
  title "Endurecimiento de SSH"

  local with_keys
  with_keys=$(count_sudo_users_with_keys)
  if [[ $with_keys -lt 1 ]]; then
    fail "ningún usuario con sudo tiene authorized_keys: apagar las contraseñas ahora te deja afuera"
    todo "corré primero el paso team-keys y verificá que entrás con clave desde otra terminal"
    return 1
  fi
  ok "$with_keys usuario(s) con sudo tienen clave autorizada"

  write_file "$SSHD_DROPIN" 0644 <<'EOF'
# Gestionado por scripts/bootstrap-server.sh — ver docs/03-entorno-servidor.md
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
EOF

  # Nunca recargar una configuración que no valida.
  if [[ $APPLY == true ]]; then
    if sshd -t; then
      ok "sshd -t valida la configuración"
      run systemctl reload ssh
    else
      die "sshd -t falló: NO se recargó el servicio. Revisá $SSHD_DROPIN"
    fi
  else
    log "  ${C_YELLOW}[dry-run]${C_RESET} validaría con 'sshd -t' y recargaría ssh"
  fi

  todo "antes de cerrar esta sesión, abrí OTRA terminal y comprobá que podés entrar por SSH"
}

sshd_port() {
  local port=''
  port=$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}') || true
  printf '%s\n' "${port:-22}"
}

step_firewall() {
  title "Cortafuegos (ufw)"
  local port
  port=$(sshd_port)

  # El orden importa: primero la regla de SSH, después habilitar. Al revés te
  # quedás afuera de tu propio servidor.
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw allow "$port/tcp" comment 'SSH'

  if ufw status 2>/dev/null | head -1 | grep -q 'Status: active'; then
    ok "ufw ya estaba activo"
  else
    run ufw --force enable
  fi

  log "  Ollama escucha sólo en 127.0.0.1: no se abre ningún puerto para el modelo."
}

# Sólo diagnostica. La decisión de cómo se entra desde afuera es tuya.
step_remote_access() {
  title "Acceso remoto: diagnóstico (no cambia nada)"

  local public_ip=''
  public_ip=$(curl --fail --silent --max-time 5 https://api.ipify.org || true)
  if [[ -z $public_ip ]]; then
    warn "no se pudo averiguar la IP pública (¿sin salida a internet?)"
  else
    log "  IP pública vista desde afuera: $public_ip"
  fi

  local gw=''
  gw=$(ip route show default | awk '/default/{print $3; exit}') || true
  log "  gateway de la LAN: ${gw:-desconocido}"

  if command -v traceroute >/dev/null 2>&1; then
    log "  primeros saltos (buscá 100.64.0.0/10 = CGNAT del ISP):"
    traceroute -n -m 4 -w 2 "${public_ip:-1.1.1.1}" 2>/dev/null | sed 's/^/    /' || true
  else
    warn "sin traceroute: instalalo con 'apt-get install traceroute' para descartar CGNAT"
  fi

  todo "elegí cómo entra el equipo desde afuera y anotalo en el issue #1:"
  log "     · túnel (Cloudflare Tunnel o Tailscale): funciona con CGNAT, no abre puertos"
  log "     · redirección de puerto + DNS dinámico: sólo si tenés IP pública real"
  log "     · nada: el servidor queda sólo en la LAN y el plan B de cloud (#4) sube de prioridad"
}

step_verify() {
  title "Verificación"

  if [[ -f $SYSCTL_FILE ]]; then ok "$SYSCTL_FILE existe"; else fail "falta $SYSCTL_FILE"; fi

  local want got key
  for key in fs.inotify.max_user_watches:524288 \
             fs.inotify.max_user_instances:512 \
             fs.inotify.max_queued_events:32768; do
    want=${key#*:}
    got=$(sysctl --values "${key%%:*}" 2>/dev/null || echo '?')
    if [[ $got == "$want" ]]; then ok "${key%%:*} = $got"; else fail "${key%%:*} = $got (esperado $want)"; fi
  done

  if sshd -T 2>/dev/null | grep -qx 'passwordauthentication no'; then
    ok "PasswordAuthentication no"
  else
    fail "PasswordAuthentication sigue habilitado"
  fi

  if sshd -T 2>/dev/null | grep -qx 'permitrootlogin no'; then
    ok "PermitRootLogin no"
  else
    fail "PermitRootLogin no está en 'no'"
  fi

  if ufw status 2>/dev/null | head -1 | grep -q 'Status: active'; then
    ok "ufw activo"
    ufw status verbose 2>/dev/null | grep -E '^Default:' | sed 's/^/  /'
  else
    fail "ufw inactivo"
  fi

  if is_laptop; then
    if [[ -f $LOGIND_DROPIN ]]; then ok "logind configurado para ignorar la tapa"; else fail "falta $LOGIND_DROPIN"; fi
  fi

  local with_keys
  with_keys=$(count_sudo_users_with_keys)
  if [[ $with_keys -ge 1 ]]; then ok "$with_keys usuario(s) con sudo y clave"; else fail "nadie con sudo tiene clave autorizada"; fi

  if systemctl is-enabled --quiet ssh 2>/dev/null; then ok "ssh habilitado al arranque"; else fail "ssh no está habilitado"; fi

  printf '\n'
  if [[ $FAILED_CHECKS -eq 0 ]]; then
    printf '%s%d comprobaciones fallidas: el servidor cumple los criterios de #1.%s\n' "$C_GREEN" "$FAILED_CHECKS" "$C_RESET"
  else
    printf '%s%d comprobación(es) fallida(s).%s\n' "$C_RED" "$FAILED_CHECKS" "$C_RESET"
  fi
}

# --------------------------------------------------------------------------
# Argumentos y arranque
# --------------------------------------------------------------------------

usage() {
  # Imprime la cabecera del propio script: la documentación y la ayuda no
  # pueden divergir si son el mismo texto.
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

step_exists() {
  local candidate=$1 s
  for s in "${ALL_STEPS[@]}"; do
    [[ $s == "$candidate" ]] && return 0
  done
  return 1
}

parse_args() {
  local only=() skip=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --apply)       APPLY=true ;;
      --keys-dir)    KEYS_DIR=${2:?--keys-dir necesita un directorio}; shift ;;
      --only)        step_exists "${2:?}" || die "paso desconocido: $2"; only+=("$2"); shift ;;
      --skip)        step_exists "${2:?}" || die "paso desconocido: $2"; skip+=("$2"); shift ;;
      --list-steps)  printf '%s\n' "${ALL_STEPS[@]}"; exit 0 ;;
      -h|--help)     usage; exit 0 ;;
      *)             die "argumento desconocido: $1 (probá --help)" ;;
    esac
    shift
  done

  if [[ ${#only[@]} -gt 0 ]]; then
    STEPS=("${only[@]}")
  fi

  if [[ ${#skip[@]} -gt 0 ]]; then
    local remaining=() s k keep
    for s in "${STEPS[@]}"; do
      keep=true
      for k in "${skip[@]}"; do
        [[ $s == "$k" ]] && keep=false
      done
      [[ $keep == true ]] && remaining+=("$s")
    done
    STEPS=("${remaining[@]}")
  fi
}

main() {
  parse_args "$@"

  [[ $(id -u) -eq 0 ]] || die "hay que correrlo como root: sudo ./scripts/$SCRIPT_NAME"

  if [[ ! -f /etc/debian_version ]]; then
    die "esto está escrito para Debian. /etc/debian_version no existe."
  fi

  if [[ $APPLY == true ]]; then
    printf '%s modo APPLY: se van a modificar archivos del sistema.%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
  else
    printf '%s modo dry-run: no se modifica nada. Agregá --apply cuando hayas leído la salida.%s\n' \
      "$C_BOLD" "$C_RESET"
  fi
  log "pasos: ${STEPS[*]}"

  local step
  for step in "${STEPS[@]}"; do
    case $step in
      inventory)     step_inventory ;;
      packages)      step_packages ;;
      sysctl)        step_sysctl ;;
      logind)        step_logind ;;
      team-keys)     step_team_keys || true ;;
      ssh-hardening) step_ssh_hardening || true ;;
      firewall)      step_firewall ;;
      remote-access) step_remote_access ;;
      verify)        step_verify ;;
    esac
  done

  printf '\n'
  if [[ $APPLY != true ]]; then
    log "Nada se modificó. Volvé a correrlo con --apply cuando la salida de arriba te cierre."
  fi

  [[ $FAILED_CHECKS -eq 0 ]] || exit 1
}

main "$@"
