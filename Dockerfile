FROM alpine:latest
WORKDIR /app

# 安装依赖
RUN apk add --no-cache wget dante-server

# 安装 FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar zxf frp.tar.gz \
    && cd frp_* \
    && cp frps frpc /usr/bin/

# 服务端 FRP 配置
RUN cat > frps.ini << EOF
[common]
bind_port = 7000
token = railway_frp_123
EOF

# 客户端B 配置（提供代理）
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

# 客户端B 内置 SOCKS5 代理配置
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: lo
socksmethod: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
EOF

# 启动脚本（路径已修正）
RUN cat > /app/start.sh << EOF
#!/bin/sh
sockd -D
frps -c frps.ini &
frpc -c frpc.ini
EOF

# 赋予执行权限
RUN chmod +x /app/start.sh

# 暴露端口
EXPOSE 7000 10800

# 执行路径已修正为 /app/start.sh
CMD ["/app/start.sh"]
