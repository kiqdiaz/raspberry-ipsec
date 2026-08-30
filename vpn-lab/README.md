# vpn-lab — concentrador VPN emulado para probar `raspi-backup-link`

Entorno Docker Compose para correr en un Mac mini y emular el concentrador
VPN (tipo Fortigate) al que la Raspberry Pi (`../`) le levanta el túnel
IPSEC. Sirve para probar el proyecto de punta a punta sin depender de
hardware real de concentrador.

## Arquitectura

```
                 UDP 500/4500 (NAT-T)              red "wan" (bridge, NAT de Docker)
Raspberry Pi ───────────────────────────►  [ concentrator ]
 (detrás de NAT)                            strongSwan/IKEv2
                                             leftsubnet=10.255.0.0/24
                                                     │
                                             internal_lan (10.255.0.0/24, internal:true)
                                                     │
                                             [ web ] nginx — 10.255.0.1
                                             (== BRANCH_TEST_IP de la Pi)
```

- **`concentrator`**: strongSwan clásico (`ipsec.conf`, igual que en la Pi),
  responde el túnel con IP fija, con NAT-T forzado (`forceencaps=yes`).
  Como el NAT-T encapsula ESP dentro de UDP 4500, **todo** el tráfico del
  túnel (IKE y ESP) viaja por los puertos `500/udp` y `4500/udp`
  publicados por Docker — no hace falta reenviar el protocolo IP 50 ni usar
  una red `macvlan` (que en Docker Desktop para Mac es poco confiable).
- **`internal_lan`**: red Docker marcada `internal: true` — Docker no le da
  salida a Internet ni al host. El único contenedor con un pie en esta red
  y otro en `wan` es `concentrator`, que enruta (dentro de su propio
  namespace de red) el tráfico ya descifrado del túnel hacia aquí.
- **`web`**: nginx solo conectado a `internal_lan`. No tiene ninguna otra
  red ni puerto publicado — la única forma de alcanzarlo es que el tráfico
  llegue cifrado por el túnel IPSEC, se descifre en `concentrator`, y se
  enrute hacia `10.255.0.1`.

## Requisitos previos en el Mac mini

1. Docker Desktop instalado (Apple Silicon, ok con M4).
2. **IP fija del Mac mini en tu LAN**: asígnala como IP estática en macOS
   (Ajustes de Red) o como reserva DHCP en tu router. Docker Compose *no*
   gestiona esto — es la IP física de la máquina, no de un contenedor.
   Esa es la IP que va en `IPSEC_VPN_CONCENTRATOR_IP` del `.env` de la Pi.
3. Puertos `500/udp` y `4500/udp` deben llegar hasta esa IP (si la Pi está
   en la misma LAN detrás de un router/AP intermedio que le hace NAT, no
   necesitas port-forwarding adicional; si el Mac mini está detrás de su
   propio NAT/firewall — p. ej. probando por Internet — deberás reenviar
   esos dos puertos hacia él).

## Configuración

```bash
cd vpn-lab
cp .env.example .env
nano .env
```

Los valores de `vpn-lab/.env` deben **coincidir exactamente** (con
local/remoto invertidos) con los del `.env` real de la Raspberry Pi:

| vpn-lab/.env (concentrador) | ../.env (Raspberry Pi)  |
|------------------------------|--------------------------|
| `CONCENTRATOR_ID`            | `IPSEC_REMOTE_ID`        |
| `NODE_ID`                    | `IPSEC_LOCAL_ID`         |
| `IPSEC_PSK`                  | `IPSEC_PSK`              |
| `CONCENTRATOR_SUBNET`        | `IPSEC_REMOTE_SUBNET`    |
| `NODE_SUBNET`                | `IPSEC_LOCAL_SUBNET`     |
| `IKE_PROPOSAL`               | `IPSEC_IKE_PROPOSAL`     |
| `ESP_PROPOSAL`               | `IPSEC_ESP_PROPOSAL`     |

Con los valores por defecto de ambos `.env.example` no hace falta tocar
nada en la Pi: `WEB_CONTAINER_IP=10.255.0.1` ya coincide con
`BRANCH_TEST_IP` de la Pi, así `scripts/07-check-branch.sh` funciona sin
cambios.

**Nota sobre `NODE_SUBNET`**: debe ser exactamente la red (o `/32`) que la
Pi anuncia como `leftsubnet`, es decir la IP real de su interfaz
(`ETH_LOCAL_IP/ETH_CIDR` o `LOOPBACK_IP/32` según `ETH_MODE`, ver
`../README.md`). Si en tu laboratorio la Pi corre con `ETH_MODE=none` y no
tiene una red L3 real de por medio, la forma más simple es usar
`ETH_MODE=console` con un `LOOPBACK_IP/32` como selector en ambos lados.

Si cambias `CONCENTRATOR_SUBNET` a algo distinto de `10.255.0.0/24`,
actualiza también el `gateway` de `internal_lan` en `docker-compose.yml`
(hoy fijo en `10.255.0.254`) para que quede dentro de la subred nueva.

## Levantar el laboratorio

```bash
docker compose up -d --build
docker compose logs -f concentrator
```

Deberías ver el mensaje de arranque de `entrypoint.sh` y luego los logs de
strongSwan escuchando en 500/4500.

## Probar desde la Raspberry Pi

En la Pi, con su `.env` ya apuntando a la IP fija del Mac mini:

```bash
sudo scripts/05-configure-ipsec.sh
scripts/06-check-ipsec.sh      # debe mostrar ESTABLISHED
scripts/07-check-branch.sh     # ping a 10.255.0.1 a través del túnel
curl http://10.255.0.1/        # debe devolver el HTML de prueba
```

## Diagnóstico en el Mac mini

```bash
docker compose exec concentrator ipsec statusall
docker compose logs -f concentrator
docker compose exec concentrator ip route     # debe existir ruta a NODE_SUBNET vía la interfaz "wan"
```

Problemas comunes:

- **No hay `ESTABLISHED`**: revisa que `IPSEC_PSK`, `CONCENTRATOR_ID`/`NODE_ID`
  y las propuestas IKE/ESP coincidan exactamente en ambos `.env`.
- **Túnel `ESTABLISHED` pero sin tráfico (ping/curl fallan)**: revisa que
  `NODE_SUBNET`/`CONCENTRATOR_SUBNET` sean exactamente los selectores de
  fase 2 correctos en ambos lados (deben "casar" en Docker y en la Pi).
- **UDP 500/4500 no llegan**: confirma la IP fija del Mac mini y que nada
  en el camino (firewall del router, VPN del propio Mac) bloquee esos
  puertos hacia él.
