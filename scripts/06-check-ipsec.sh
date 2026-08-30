#!/usr/bin/env bash
# Valida que el túnel IPSEC 'backup-link' esté establecido.
source "$(dirname "$0")/../lib/common.sh"

load_env
require_cmd ipsec

log "Estado de strongSwan:"
ipsec statusall backup-link || true

if ipsec statusall backup-link 2>/dev/null | grep -q "ESTABLISHED"; then
    log "Túnel IPSEC 'backup-link': ESTABLISHED (OK)"
    exit 0
else
    err "Túnel IPSEC 'backup-link' no está establecido. Revisar PSK, IDs y alcance del concentrador (${IPSEC_VPN_CONCENTRATOR_IP:-?})."
    exit 1
fi
