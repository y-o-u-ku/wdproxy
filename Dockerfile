FROM alpine:latest
WORKDIR /app

# 安装依赖 + 强制允许 pip 安装（修复关键）
RUN apk add --no-cache wget python3 py3-pip dante-server \
    && pip3 install flask --no-cache-dir --break-system-packages

# 安装 FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar -zxvf frp.tar.gz \
    && cd frp_* \
    && cp frps /usr/bin/ \
    && cp frpc /usr/bin/ \
    && chmod +x /usr/bin/frps /usr/bin/frpc

# frp 服务端配置
RUN cat > /app/frps.ini << EOF
[common]
bind_port = 7000
token = frp_2025
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
EOF

# frp 客户端 B 配置
RUN cat > /app/frpc.ini << EOF
[common]
server_addr = 127.0.0.1
server_port = 7000
token = frp_2025

[socks5_b]
type = tcp
local_ip = 127.0.0.1
local_port = 1080
remote_port = 10800
EOF

# SOCKS5 代理（客户端B 上网用）
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: 0.0.0.0
method: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
logoutput: /var/log/sockd.log
EOF

# Web 管理面板
RUN cat > /app/app.py << EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>FRP 代理：A → 服务端 → B → 公网</h1>
    <h3>客户端 A 配置</h3>
    <textarea rows=10 cols=60>
[common]
server_addr = 你的服务器IP
server_port = 7000
token = frp_2025
    </textarea>
    <h3>客户端A 代理</h3>
    <p>SOCKS5：服务器IP:10800</p>
    <p>全部流量走 B 访问公网</p>
'''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

# 启动脚本
RUN cat > /app/start.sh << EOF
#!/bin/sh
sockd -D
frps -c /app/frps.ini &
frpc -c /app/frpc.ini &
python3 /app/app.py &

echo "====================================="
echo "✅ 启动成功！"
echo "🌐 Web面板：http://本机IP:8080"
echo "🔗 客户端A代理：服务器IP:10800 (SOCKS5)"
echo "====================================="

tail -f /dev/null
EOF

RUN chmod +x /app/start.sh

EXPOSE 7000 8080 10800 7500
CMD ["/app/start.sh"]
