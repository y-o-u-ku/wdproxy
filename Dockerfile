FROM alpine:latest

# 安装依赖
RUN apk update && apk add --no-cache \
    wireguard-tools \
    iptables \
    bash \
    iproute2

# 自动生成所有配置 + 启动
RUN cat > /run.sh <<'EOF'
#!/bin/bash
set -e

# 固定网段
PORT=51820
WG_SERVER_IP=10.0.0.1/24
CLIENT_A_IP=10.0.0.2/32

# 自动生成所有密钥
mkdir -p /etc/wireguard
SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)
CLIENT_A_PRIV=$(wg genkey)
CLIENT_A_PUB=$(echo "$CLIENT_A_PRIV" | wg pubkey)

# 生成 WireGuard 服务端配置（容器内的 Server）
cat > /etc/wireguard/wg0.conf <<CONF
[Interface]
PrivateKey = $SERVER_PRIV
Address = $WG_SERVER_IP
ListenPort = $PORT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_A_PUB
AllowedIPs = $CLIENT_A_IP
CONF

# 开启内核转发
sysctl -w net.ipv4.ip_forward=1
iptables -F

# 启动 WireGuard
wg-quick up wg0

# 输出本地 A 客户端配置（直接复制用）
clear
echo -e "\n========================================"
echo -e "   WireGuard 启动成功！A 客户端配置如下"
echo -e "========================================\n"

cat <<CONF
[Interface]
PrivateKey = $CLIENT_A_PRIV
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUB
Endpoint = 127.0.0.1:$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF

echo -e "\n========================================\n"

# 保持容器运行
tail -f /dev/null
EOF

RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]
