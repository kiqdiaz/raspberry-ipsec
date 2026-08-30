#!/usr/bin/env bash
# Funciones compartidas por los scripts de scripts/. Se importa con:
#   source "$(dirname "$0")/../lib/common.sh"
set -euo pipefail

RASPI_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${RASPI_PROJECT_ROOT}/.env"

log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
err()  { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die()  { err "$*"; exit 1; }

load_env() {
    [ -f "$ENV_FILE" ] || die "No existe $ENV_FILE. Copia .env.example como .env y complétalo."
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
}

require_root() {
    [ "$(id -u)" -eq 0 ] || die "Este script requiere privilegios de root (usar sudo)."
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Falta el comando '$1'. Ejecuta scripts/00-install-deps.sh."
}

# Asegura que el tráfico originado en esta Raspberry Pi hacia la subred
# remota del túnel (IPSEC_REMOTE_SUBNET) elija como IP origen la identidad
# local del túnel (ETH_LOCAL_IP o LOOPBACK_IP, según ETH_MODE), en vez de la
# IP del enlace WiFi por defecto. Sin esta ruta, el kernel resuelve el
# origen por la tabla de rutas normal (WiFi), el paquete no calza con la
# política IPSEC (leftsubnet) y sale sin cifrar por la ruta por defecto.
ensure_remote_subnet_route() {
    local dev="$1" src="$2"
    if [ -z "${IPSEC_REMOTE_SUBNET:-}" ]; then
        log "Aviso: IPSEC_REMOTE_SUBNET no está definido aún en .env; la ruta hacia la subred remota se creará la próxima vez que se ejecute este script, una vez completada esa sección."
        return 0
    fi
    log "Asegurando ruta hacia ${IPSEC_REMOTE_SUBNET} (subred remota IPSEC) con origen ${src} vía ${dev}..."
    ip route replace "${IPSEC_REMOTE_SUBNET}" dev "${dev}" src "${src}"
}
