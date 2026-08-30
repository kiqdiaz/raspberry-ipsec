#!/usr/bin/env bash
# Configura la conexión Ethernet (puerto RJ45 integrado del Raspberry Pi
# 3 B+) hacia el puerto OOB de un switch, o la interfaz loopback /32 usada
# en el caso de puerto de consola. Es una fase OPCIONAL: si ETH_MODE=none,
# se omite.
source "$(dirname "$0")/../lib/common.sh"

require_root
load_env

mode="${ETH_MODE:-none}"

case "$mode" in
    none)
        log "ETH_MODE=none: no hay cable conectado al puerto RJ45, se omite esta fase."
        exit 0
        ;;
    direct|switch)
        require_cmd ip
        iface="${ETH_IFACE:-eth0}"
        cidr="${ETH_CIDR:?ETH_CIDR no definido en .env}"

        if [ "$mode" = "direct" ] && [ "$cidr" != "30" ] && [ "$cidr" != "31" ]; then
            log "Aviso: ETH_MODE=direct normalmente usa /30 o /31 (actual: /${cidr})."
        fi
        if [ "$mode" = "switch" ] && [ "$cidr" -gt 29 ] 2>/dev/null; then
            log "Aviso: ETH_MODE=switch normalmente usa /29 o menor (actual: /${cidr})."
        fi

        log "Esperando a que ${iface} (RJ45 integrado) esté presente..."
        for i in $(seq 1 10); do
            ip link show "$iface" >/dev/null 2>&1 && break
            sleep 1
        done
        ip link show "$iface" >/dev/null 2>&1 || die "Interfaz ${iface} no detectada en el sistema."

        log "Configurando ${iface} con ${ETH_LOCAL_IP}/${cidr} (modo: ${mode})..."
        ip addr flush dev "$iface"
        ip addr add "${ETH_LOCAL_IP}/${cidr}" dev "$iface"
        ip link set "$iface" up
        ;;
    console)
        require_cmd ip
        loif="${LOOPBACK_IFACE:-loopback0}"
        lip="${LOOPBACK_IP:?LOOPBACK_IP no definido en .env}"

        log "Modo consola: asignando ${lip}/32 a interfaz loopback ${loif}..."
        modprobe dummy numdummies=0 2>/dev/null || true
        if ! ip link show "$loif" >/dev/null 2>&1; then
            ip link add "$loif" type dummy
        fi
        ip addr flush dev "$loif"
        ip addr add "${lip}/32" dev "$loif"
        ip link set "$loif" up

        log "Recordatorio: el acceso físico al switch es por puerto de consola (${CONSOLE_DEVICE:-/dev/ttyUSB0}, ${CONSOLE_BAUD:-9600} baud)."
        log "La IP ${lip}/32 identifica a este nodo para el túnel IPSEC, no hay adyacencia L3 directa con el switch."
        ;;
    *)
        die "ETH_MODE desconocido: '${mode}' (valores válidos: none, direct, switch, console)"
        ;;
esac

log "Configuración de Ethernet/loopback completada."
