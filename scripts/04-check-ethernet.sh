#!/usr/bin/env bash
# Valida la conectividad hacia el dispositivo conectado por el puerto RJ45
# integrado (puerto OOB de un switch) o el estado de la loopback en modo consola.
source "$(dirname "$0")/../lib/common.sh"

load_env
require_cmd ip

mode="${ETH_MODE:-none}"

case "$mode" in
    none)
        log "ETH_MODE=none: sin conexión Ethernet (RJ45) que validar. Fase omitida."
        exit 0
        ;;
    direct|switch)
        iface="${ETH_IFACE:-eth0}"
        peer="${ETH_PEER_IP:?ETH_PEER_IP no definido en .env}"

        log "Estado de ${iface}:"
        ip -4 addr show "$iface" || die "Interfaz ${iface} no existe."

        log "Verificando conectividad hacia el switch (${peer})..."
        if ping -c 3 -W 3 "$peer" >/dev/null 2>&1; then
            log "Conectividad Ethernet (modo ${mode}): OK"
            exit 0
        else
            err "No hay respuesta de ${peer}. Revisar cableado, VLAN/puerto OOB y la IP configurada."
            exit 1
        fi
        ;;
    console)
        loif="${LOOPBACK_IFACE:-loopback0}"
        log "Estado de la interfaz loopback ${loif}:"
        ip -4 addr show "$loif" || die "Interfaz ${loif} no existe."
        log "Modo consola: no hay adyacencia L3 con el switch para validar por ping."
        log "Verificar manualmente el acceso serie: screen ${CONSOLE_DEVICE:-/dev/ttyUSB0} ${CONSOLE_BAUD:-9600}"
        exit 0
        ;;
    *)
        die "ETH_MODE desconocido: '${mode}'"
        ;;
esac
