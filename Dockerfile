FROM alpine:latest
WORKDIR /app

# 安装依赖（兼容Railway）
RUN apk add --no-cache wget python3 py3-pip dante-server \
    && pip3 install flask --no-cache-dir --break-system-packages --root-user-action=ignore

# 安装FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar zxf frp.tar.gz \
    && cd frp_* \
    && cp frps frpc /usr/bin/ \
    && chmod +x /usr/bin/frp*

# --------------------------
# FRP 服务端（Railway 公开端口）
# --------------------------
RUN cat > frps.ini << EOF
[common]
bind_port = 7000
token = railway_frp_123
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
EOF

# --------------------------
# 客户端 B（本地连接服务端）
# --------------------------
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

# --------------------------
# SOCKS5 代理
# --------------------------
RUN cat > /etc/sockd.conf << EOF
internal: 0.0.0.0 port = 1080
external: 0.0.0.0
method: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
logoutput: /dev/null
EOF

# --------------------------
# Web 面板 (Railway 必须 0.0.0.0)
# --------------------------
RUN cat > app.py << EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return '''
<h1>Railway FRP 代理运行成功</h1>
<h3>客户端 A 配置</h3>
<textarea rows=10 cols=60>
[common]
server_addr = 你的R ailway域名
server_port = 7000
token = railway_frp_123
</textarea>
<h3>SOCKS5 代理</h3>
<p>服务器：你的Railway域名</p>
<p>端口：10800</p>
'''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, threaded=True)
EOF

# --------------------------
# 启动脚本（Railway 兼容，不阻塞）
# --------------------------
RUN cat > start.sh << EOF
#!/bin/sh
echo "启动 socks5 代理..."
sockd -D &
sleep 1

echo "启动 frp 服务端..."
frps -c frps.ini &
sleep 2

echo "启动 frp 客户端 B..."
frpc -c frpc.ini &
sleep 1

echo "启动 Web 面板..."
python3 app.py
EOF

RUN chmod +x start.sh

# 暴露 Railway 可用端口
EXPOSE 7000 8080 10800 7500

CMD ["/app/start.sh"]
