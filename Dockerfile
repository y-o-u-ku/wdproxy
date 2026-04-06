FROM alpine:latest

# 安装依赖
RUN apk update && apk add --no-cache \
    wireguard-tools \
    iptables \
    bash \
    iproute2

# 全自动启动脚本（Railway 兼容版）
RUN cat > /run.sh <<'EOF'
#!/bin/bash
set -e

# 固定配置
PORT=51820
SERVER_IP=10.0.0.1/24
CLIENT_A_IP=10.0.0.2/32

# 自动生成密钥
mkdir -p /etc/wireguard
SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)
CLIENT_A_PRIV=$(wg genkey)
CLIENT_A_PUB=$(echo "$CLIENT_A_PRIV" | wg pubkey)

# 生成 WireGuard 配置
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

# 启动 WireGuard（无 sysctl，Railway 兼容）
iptables -F 2>/dev/null || true
wg-quick up wg0 2>/dev/null || true

# 输出客户端 A 配置（直接复制用）
echo -e "\n========================================"
echo -e "  WireGuard 启动成功！本地 A 配置如下"
echo -e "========================================\n"

cat <<CONF
[Interface]
PrivateKey = $CLIENT_A_PRIV
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUB
# 👇 这里必须换成你的 Railway 域名:端口
Endpoint = $RAILWAY_PUBLIC_DOMAIN:$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF

echo -e "\n========================================\n"
tail -f /dev/null
EOF

RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]
