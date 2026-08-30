#!/usr/bin/env bash
# Configura el WiFi como enlace de respaldo hacia Internet, a partir de .env.
source "$(dirname "$0")/../lib/common.sh"

require_root
load_env

[ -n "${WIFI_SSID:-}" ] || die "WIFI_SSID no está definido en .env"

WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-${WIFI_IFACE}.conf"

log "Generando ${WPA_CONF} para SSID '${WIFI_SSID}' en ${WIFI_IFACE}..."
envsubst < "${RASPI_PROJECT_ROOT}/config/wpa_supplicant.conf.template" > "$WPA_CONF"
chmod 600 "$WPA_CONF"

log "Habilitando y (re)iniciando wpa_supplicant@${WIFI_IFACE}..."
rfkill unblock wifi || true
ip link set "$WIFI_IFACE" up || true
systemctl enable "wpa_supplicant@${WIFI_IFACE}.service"
systemctl restart "wpa_supplicant@${WIFI_IFACE}.service"

log "Solicitando IP dinámica por DHCP en ${WIFI_IFACE}..."
if command -v dhclient >/dev/null 2>&1; then
    dhclient -v "$WIFI_IFACE" || true
elif command -v nmcli >/dev/null 2>&1; then
    nmcli device connect "$WIFI_IFACE" || true
else
    log "Aviso: no se encontró dhclient/nmcli; verificar el cliente DHCP en uso."
fi

log "WiFi configurado. Verificar con scripts/02-check-internet.sh"
