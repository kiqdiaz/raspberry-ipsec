#!/usr/bin/env bash
# Confirma la conectividad a Internet a través del enlace WiFi (IP dinámica tipo "dial up").
source "$(dirname "$0")/../lib/common.sh"

load_env
require_cmd ping

hosts="${INTERNET_CHECK_HOSTS:-1.1.1.1 8.8.8.8}"
timeout="${INTERNET_CHECK_TIMEOUT:-5}"

log "Interfaz ${WIFI_IFACE:-wlan0}:"
ip -4 addr show "${WIFI_IFACE:-wlan0}" 2>/dev/null || log "  (interfaz no encontrada)"

ok=0
for host in $hosts; do
    log "Probando conectividad hacia ${host}..."
    if ping -c 3 -W "$timeout" -I "${WIFI_IFACE:-wlan0}" "$host" >/dev/null 2>&1; then
        log "  OK: ${host} responde."
        ok=1
        break
    else
        log "  Sin respuesta de ${host}."
    fi
done

if [ "$ok" -eq 1 ]; then
    log "Conectividad a Internet: OK"
    exit 0
else
    err "Conectividad a Internet: FALLA. Revisar SSID/clave, señal WiFi y IP asignada por DHCP."
    exit 1
fi
