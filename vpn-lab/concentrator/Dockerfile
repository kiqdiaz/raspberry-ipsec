FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        strongswan \
        strongswan-starter \
        libcharon-extra-plugins \
        libstrongswan-extra-plugins \
        iproute2 \
        iptables \
        iputils-ping \
        gettext-base \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY strongswan.conf /etc/strongswan.conf
COPY ipsec.conf.template /etc/ipsec.conf.template
COPY ipsec.secrets.template /etc/ipsec.secrets.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
