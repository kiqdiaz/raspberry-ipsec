#!/usr/bin/env bash
# Valida conectividad de extremo a extremo hacia un dispositivo branch de
# prueba, alcanzable a través del túnel IPSEC.
source "$(dirname "$0")/../lib/common.sh"

load_env
require_cmd ping

target="${BRANCH_TEST_IP:?BRANCH_TEST_IP no definido en .env}"
timeout="${BRANCH_CHECK_TIMEOUT:-5}"

log "Probando conectividad hacia el dispositivo branch de prueba (${target}) a través del túnel..."
if ping -c 4 -W "$timeout" "$target" >/dev/null 2>&1; then
    log "Conectividad hacia ${target}: OK. El enlace de respaldo está operativo de extremo a extremo."
    exit 0
else
    err "Sin respuesta de ${target}. Revisar rightsubnet/leftsubnet del túnel y ruteo en el concentrador."
    exit 1
fi
