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

# Los demás contenedores de internal_lan (p. ej. "web") no tienen ruta de
# vuelta hacia NODE_SUBNET: su gateway por defecto es el propio bridge de
# Docker (no este contenedor), así que un paquete de respuesta dirigido al
# nodo remoto se pierde ahí. Se enmascara (hairpin NAT) el tráfico
# reenviado desde el túnel hacia CONCENTRATOR_SUBNET para que salga con
# origen la IP de este concentrador en esa red: al estar en el mismo
# segmento, la respuesta vuelve directo por L2, sin depender de ningún
# gateway.
iptables -t nat -C POSTROUTING -s "${NODE_SUBNET}" -d "${CONCENTRATOR_SUBNET}" -j MASQUERADE 2>/dev/null \
    || iptables -t nat -A POSTROUTING -s "${NODE_SUBNET}" -d "${CONCENTRATOR_SUBNET}" -j MASQUERADE

echo "Concentrador VPN emulado."
echo "  Nodo esperado (rightid):    ${NODE_ID}"
echo "  Selector del nodo:          ${NODE_SUBNET}"
echo "  Red local expuesta (leftsubnet, hacia internal_lan): ${CONCENTRATOR_SUBNET}"

exec ipsec start --nofork
