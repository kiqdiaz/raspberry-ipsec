#!/usr/bin/env bash
# Renderiza ipsec.conf/ipsec.secrets a partir de las variables de entorno
# (.env vía docker compose) y arranca strongSwan en primer plano.
set -euo pipefail

for var in CONCENTRATOR_ID NODE_ID IPSEC_PSK CONCENTRATOR_SUBNET NODE_SUBNET \
           IKE_PROPOSAL ESP_PROPOSAL IPSEC_DPD_DELAY IPSEC_DPD_TIMEOUT; do
    : "${!var:?falta la variable ${var} en .env}"
done

envsubst < /etc/ipsec.conf.template > /etc/ipsec.conf
envsubst < /etc/ipsec.secrets.template > /etc/ipsec.secrets
chmod 600 /etc/ipsec.secrets

sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

echo "Concentrador VPN emulado."
echo "  Nodo esperado (rightid):    ${NODE_ID}"
echo "  Selector del nodo:          ${NODE_SUBNET}"
echo "  Red local expuesta (leftsubnet, hacia internal_lan): ${CONCENTRATOR_SUBNET}"

exec ipsec start --nofork
