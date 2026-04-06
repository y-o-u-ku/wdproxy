FROM alpine:latest
WORKDIR /app

# 安装依赖
RUN apk add --no-cache wget python3 py3-pip dante-server

# 安装 FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar zxf frp.tar.gz \
    && cd frp_* \
    && cp frps frpc /usr/bin/ \
    && chmod +x /usr/bin/frp*

# ---------------------
# 服务端 frps
# ---------------------
RUN cat > frps.ini << EOF
[common]
bind_port = 7000
token = railway_frp_123
EOF

# ---------------------
# 客户端B（真正的代理端！！！我之前写反了！）
# ---------------------
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

# ---------------------
# 客户端B 内置 SOCKS5 代理（关键！）
# ---------------------
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: lo
socksmethod: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
EOF

# ---------------------
# Web 面板
# ---------------------
RUN cat > app.py << EOF
from flask import Flask
import os
app = Flask(__name__)

@app.route('/')
def index():
    return "<h1>✅ 服务端运行成功</h1>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

# ---------------------
# 启动顺序（正确！）
# ---------------------
RUN cat > start.sh << EOF
#!/bin/sh
sockd -D &
sleep 1
frps -c frps.ini &
sleep 2
frpc -c frpc.ini &
python3 app.py
EOF

RUN chmod +x start.sh
EXPOSE 7000 8080 10800
CMD ["/app/start.sh"]
