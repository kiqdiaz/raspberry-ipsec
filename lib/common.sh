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
