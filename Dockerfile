FROM alpine:latest
WORKDIR /app

RUN apk add --no-cache wget dante-server

# 安装 FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar zxf frp.tar.gz \
    && cd frp_* \
    && cp frps frpc /usr/bin/

# frps 服务端配置
RUN cat > frps.ini << EOF
[common]
bind_port = 7000
token = railway_frp_123
EOF

# frpc 客户端B 配置
RUN cat > frpc.ini << EOF
[common]
server_addr = 127.0.0.1
server_port = 7000
token = railway_frp_123

[socks5]
type = tcp
local_ip = 127.0.0.1
local_port = 1080
remote_port = 10800
EOF

# sockd 代理配置
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: lo
socksmethod: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
EOF

# ✅✅✅ 修复：等待服务端启动后再运行客户端！！！
RUN cat > start.sh << EOF
#!/bin/sh
sockd -D &
sleep 1
frps -c frps.ini &
sleep 3  # 等待3秒，保证服务端完全启动！！！
frpc -c frpc.ini
EOF

RUN chmod +x start.sh

EXPOSE 7000 10800

CMD ["/app/start.sh"]
