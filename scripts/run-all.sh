#!/usr/bin/env bash
# Ejecuta la secuencia completa de arranque del enlace de respaldo:
# WiFi -> Internet -> (opcional) Ethernet USB -> IPSEC -> branch de prueba.
source "$(dirname "$0")/../lib/common.sh"

cd "$RASPI_PROJECT_ROOT"

steps=(
    "scripts/01-configure-wifi.sh"
    "scripts/02-check-internet.sh"
    "scripts/03-configure-ethernet.sh"
    "scripts/04-check-ethernet.sh"
    "scripts/05-configure-ipsec.sh"
    "scripts/06-check-ipsec.sh"
    "scripts/07-check-branch.sh"
)

for step in "${steps[@]}"; do
    log "==> Ejecutando ${step}"
    if ! "$RASPI_PROJECT_ROOT/$step"; then
        die "Falló ${step}. Abortando secuencia."
    fi
done

log "Secuencia completa: enlace de respaldo operativo."
