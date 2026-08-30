#!/usr/bin/env bash
# Instala los paquetes requeridos en Raspberry Pi OS (Debian).
source "$(dirname "$0")/../lib/common.sh"

require_root
require_cmd apt-get

log "Actualizando índices de paquetes..."
apt-get update -y

log "Instalando dependencias (strongSwan, herramientas de red, gettext para envsubst)..."
# strongswan-starter provee el comando 'ipsec'; el metapaquete strongswan por
# sí solo instala charon-systemd (basado en swanctl) y no lo incluye.
apt-get install -y \
    strongswan \
    strongswan-starter \
    strongswan-pki \
    libcharon-extra-plugins \
    libstrongswan-extra-plugins \
    wpasupplicant \
    iproute2 \
    iputils-ping \
    gettext-base \
    usbutils

log "Dependencias instaladas correctamente."
