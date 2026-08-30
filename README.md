# raspi-backup-link

Enlace de respaldo para nodos de telecomunicaciones lineales, basado en una
**Raspberry Pi 4 Model B (2GB)** (elegida por traer **puerto RJ45 Ethernet
integrado**, evitando así un adaptador USB-RJ45 externo). El equipo se
instala en el nodo, se conecta a Internet por **WiFi** (sesión tipo "dial
up", con IP pública dinámica) y levanta un **túnel IPSEC** hacia un
concentrador VPN de IP fija. De forma opcional, se conecta por su **puerto
RJ45 integrado** al puerto **OOB** de un switch, o mediante un **adaptador
USB-serie al puerto de consola** de un switch Cisco/Huawei/Juniper, para
permitir gestión y monitoreo del equipo del nodo a través del enlace de
respaldo.

## Arquitectura del enlace

```
                    WiFi (IP dinámica)              IPSEC (IP fija)
Raspberry Pi 4B ───────────────────► Internet ───────────────► Concentrador VPN
        │
        │ RJ45 integrado (eth0) — opcional
        ▼
Puerto OOB / consola de un switch
(Cisco / Huawei / Juniper)
```

### Casos de uso de la conexión Ethernet, fase 2

| Modo (`ETH_MODE`) | Escenario                                   | Red usada             |
|--------------------|----------------------------------------------|------------------------|
| `direct`            | Patch directo Pi ↔ switch por RJ45 integrado (punto a punto) | `/30` o `/31`          |
| `switch`            | Pi conectada por RJ45 integrado a través de un switch intermedio | `/29` o menor          |
| `console`           | Acceso por puerto de consola del switch (adaptador USB-serie) | IP propia en `loopback0` `/32` |
| `none`              | No hay cable conectado al puerto RJ45         | fase omitida (opcional)|

La red local resultante (`ETH_LOCAL_IP`/`ETH_CIDR` o `LOOPBACK_IP/32`) es la
que se declara como `IPSEC_LOCAL_SUBNET` en el túnel.

## Estructura del proyecto

```
raspi/
├── .env.example                     # plantilla de variables (copiar a .env)
├── config/
│   ├── ipsec.conf.template          # plantilla de /etc/ipsec.conf (strongSwan)
│   ├── ipsec.secrets.template       # plantilla de /etc/ipsec.secrets (PSK)
│   └── wpa_supplicant.conf.template # plantilla de WiFi
├── lib/
│   └── common.sh                    # funciones compartidas (log, load_env, etc.)
├── scripts/
│   ├── 00-install-deps.sh           # instala strongSwan y herramientas
│   ├── 01-configure-wifi.sh         # configura WiFi como enlace de respaldo
│   ├── 02-check-internet.sh         # valida salida a Internet por WiFi
│   ├── 03-configure-ethernet.sh     # (opcional) IP en RJ45 integrado o loopback
│   ├── 04-check-ethernet.sh         # (opcional) valida conectividad al switch
│   ├── 05-configure-ipsec.sh        # genera config y levanta el túnel IPSEC
│   ├── 06-check-ipsec.sh            # valida que el túnel esté ESTABLISHED
│   ├── 07-check-branch.sh           # valida conectividad a un branch de prueba
│   └── run-all.sh                   # ejecuta toda la secuencia en orden
└── systemd/
    └── raspi-backup-link.service    # ejecuta run-all.sh al levantar el equipo
```

## 1. Preparar la imagen (Raspberry Pi OS)

Para una Raspberry Pi 4 Model B (2GB), sin salida de video ni periféricos, usar
**Raspberry Pi OS Lite (64-bit)** (el SoC Cortex-A72 de la 4B soporta
64-bit de forma oficial):

1. Descargar [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Elegir **Raspberry Pi OS Lite (64-bit)** como sistema operativo.
3. En las opciones avanzadas (⚙️ / Ctrl+Shift+X):
   - Habilitar **SSH** (con contraseña o clave pública).
   - Configurar **WiFi** (SSID/clave) — esto permite el primer arranque
     sin monitor; luego `scripts/01-configure-wifi.sh` gestiona el enlace
     de forma reproducible desde `.env`.
   - Definir hostname y usuario del nodo.
4. Grabar la imagen en la microSD e iniciar la Raspberry Pi.

## 2. Instalar el proyecto en la Raspberry Pi

```bash
# En la Raspberry Pi (por SSH)
sudo mkdir -p /opt/raspi-backup-link
sudo chown "$USER":"$USER" /opt/raspi-backup-link
# copiar el contenido de este repo a /opt/raspi-backup-link (scp, git clone, rsync, etc.)

cd /opt/raspi-backup-link
cp .env.example .env
nano .env   # completar SSID/clave WiFi, modo Ethernet, parámetros IPSEC y branch de prueba
```

### Variables clave de `.env`

- **WiFi**: `WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_IFACE`.
- **Ethernet/consola (opcional)**: `ETH_MODE` (`none|direct|switch|console`),
  `ETH_IFACE`, `ETH_LOCAL_IP`, `ETH_CIDR`, `ETH_PEER_IP`, `LOOPBACK_IP`.
- **IPSEC**: `IPSEC_VPN_CONCENTRATOR_IP` (IP fija del concentrador),
  `IPSEC_LOCAL_ID`/`IPSEC_REMOTE_ID`, `IPSEC_PSK`, `IPSEC_LOCAL_SUBNET`,
  `IPSEC_REMOTE_SUBNET`, `IPSEC_IKE_PROPOSAL`, `IPSEC_ESP_PROPOSAL`.
- **Branch de prueba**: `BRANCH_TEST_IP` — dispositivo alcanzable a través
  del túnel, usado para confirmar conectividad de extremo a extremo.

`.env` nunca debe subirse a un repositorio (ver `.gitignore`); contiene el
PSK del túnel.

## 3. Instalar dependencias

```bash
sudo scripts/00-install-deps.sh
```

Instala `strongswan`, `wpasupplicant`, `gettext-base` (para `envsubst`) y
utilidades de red.

## 4. Procedimiento de arranque del enlace

El procedimiento sigue el mismo orden en que se debe validar el enlace:
Internet primero, Ethernet/consola opcional, luego IPSEC, y por último el
branch de prueba.

```bash
# 1) Conectividad a Internet por WiFi (IP dinámica)
sudo scripts/01-configure-wifi.sh
scripts/02-check-internet.sh

# 2) Conexión Ethernet (RJ45 integrado) al switch — opcional, según ETH_MODE en .env
sudo scripts/03-configure-ethernet.sh
scripts/04-check-ethernet.sh

# 3) Túnel IPSEC hacia el concentrador VPN
sudo scripts/05-configure-ipsec.sh
scripts/06-check-ipsec.sh

# 4) Conectividad de extremo a extremo con el branch de prueba
scripts/07-check-branch.sh
```

O bien, ejecutar toda la secuencia de una vez:

```bash
sudo scripts/run-all.sh
```

Cada script es idempotente y puede volver a ejecutarse de forma segura
(por ejemplo tras cambiar `.env`).

## 5. Ejecutar automáticamente al arrancar la Raspberry Pi

```bash
sudo cp systemd/raspi-backup-link.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now raspi-backup-link.service
```

El servicio reintenta la secuencia cada 30 segundos si falla (por ejemplo,
si al arrancar el WiFi todavía no tiene señal).

## 6. Diagnóstico

```bash
# Estado del túnel
sudo ipsec statusall backup-link

# Logs del servicio de arranque
journalctl -u raspi-backup-link.service -f

# Logs de strongSwan
journalctl -u strongswan-starter -f
```

## Notas de diseño

- **IP dinámica local / IP fija remota**: como el proveedor de Internet
  entrega una IP dinámica (sesión "dial up" por WiFi), la configuración de
  IPSEC usa `left=%defaultroute` en lugar de una IP fija local; el
  concentrador remoto sí se referencia por IP fija (`right=<IP fija>`).
- **Fase 2 (selectores de tráfico)**: la red de origen del túnel
  (`IPSEC_LOCAL_SUBNET`) corresponde a la red del puerto RJ45 integrado
  (`eth0`): `/30` o `/31` para conexión directa, `/29` o menor si hay un
  switch de por medio. En el caso de acceso por puerto de consola, no hay
  red L3 hacia el switch; en su lugar, la IP propia del nodo se asigna a
  una interfaz loopback `/32` y esa es la que se usa como origen.
- **Por qué Raspberry Pi 4 Model B (2GB)**: a diferencia de la Zero 2 W, la 4B
  trae puerto **RJ45 Ethernet integrado** (`eth0`, además a Gigabit real por
  no compartir bus con USB como en la 3 B+), por lo que los modos `direct` y
  `switch` de `ETH_MODE` no requieren ningún adaptador USB-RJ45 externo —
  solo un cable de patch hacia el puerto OOB del switch. El WiFi (`wlan0`)
  también viene integrado y se usa igual que antes como enlace de respaldo
  hacia Internet. Los 2GB de RAM son más que suficientes para este uso
  (WiFi, IPSEC y monitoreo del enlace), sin necesidad de las variantes de
  4GB/8GB.
- **Puerto de consola**: sigue requiriendo un adaptador USB-serie
  (`CONSOLE_DEVICE`, `CONSOLE_BAUD` en `.env`), ya que la 4B no expone un
  puerto serie RS-232 nativo utilizable para esto. Se documenta como
  referencia; la automatización de comandos por consola
  (Cisco/Huawei/Juniper) queda fuera del alcance actual de estos scripts.
