#!/usr/bin/env bash
# Renderiza los templates de strongSwan a partir de .env y levanta el túnel IPSEC.
source "$(dirname "$0")/../lib/common.sh"

require_root
load_env
require_cmd envsubst
require_cmd ipsec

for var in IPSEC_VPN_CONCENTRATOR_IP IPSEC_LOCAL_ID IPSEC_REMOTE_ID IPSEC_PSK \
           IPSEC_LOCAL_SUBNET IPSEC_REMOTE_SUBNET IPSEC_IKE_PROPOSAL IPSEC_ESP_PROPOSAL; do
    [ -n "${!var:-}" ] || die "${var} no está definido en .env"
done

log "Generando /etc/ipsec.conf..."
envsubst < "${RASPI_PROJECT_ROOT}/config/ipsec.conf.template" > /etc/ipsec.conf

log "Generando /etc/ipsec.secrets (PSK)..."
envsubst < "${RASPI_PROJECT_ROOT}/config/ipsec.secrets.template" > /etc/ipsec.secrets
chmod 600 /etc/ipsec.secrets

log "Reiniciando strongSwan y levantando el túnel 'backup-link'..."
systemctl enable strongswan-starter 2>/dev/null || systemctl enable strongswan 2>/dev/null || true
systemctl restart strongswan-starter 2>/dev/null || systemctl restart strongswan 2>/dev/null || true

sleep 2
ipsec up backup-link || log "Aviso: 'ipsec up' no confirmó el establecimiento inmediato; verificar con scripts/06-check-ipsec.sh"

log "Configuración de IPSEC aplicada. Concentrador remoto: ${IPSEC_VPN_CONCENTRATOR_IP}"
