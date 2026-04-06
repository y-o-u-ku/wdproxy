FROM alpine:latest

RUN apk update && apk add --no-cache \
    wireguard-tools \
    iptables \
    bash \
    iproute2

RUN cat > /run.sh <<'EOF'
#!/bin/bash
set -e

PORT=51820
SERVER_IP=10.0.0.1/24
CLIENT_A_IP=10.0.0.2/32

mkdir -p /etc/wireguard

SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)
CLIENT_A_PRIV=$(wg genkey)
CLIENT_A_PUB=$(echo "$CLIENT_A_PRIV" | wg pubkey)

cat > /etc/wireguard/wg0.conf <<CONF
[Interface]
PrivateKey = $SERVER_PRIV
Address = $SERVER_IP
ListenPort = $PORT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_A_PUB
AllowedIPs = $CLIENT_A_IP
CONF

iptables -F 2>/dev/null
wg-quick up wg0 2>/dev/null

echo -e "\n========================================"
echo -e "  WireGuard 启动成功！本地 A 配置如下"
echo -e "========================================\n"

# 自动获取 Railway 域名
DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-localhost}

cat <<CONF
[Interface]
PrivateKey = $CLIENT_A_PRIV
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $DOMAIN:$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF

echo -e "\n========================================\n"
tail -f /dev/null
EOF

RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]
