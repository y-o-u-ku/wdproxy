FROM alpine:latest
WORKDIR /app

# 安装依赖
RUN apk add --no-cache wget python3 py3-pip dante-server \
    && pip3 install flask --no-cache-dir --break-system-packages --root-user-action=ignore

# 安装 FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar zxf frp.tar.gz \
    && cd frp_* \
    && cp frps frpc /usr/bin/ \
    && chmod +x /usr/bin/frp*

# FRP 服务端配置
RUN cat > frps.ini << EOF
[common]
bind_port = 7000
token = railway_frp_123
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
EOF

# FRP 客户端 B 配置
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

# ======================
# 修复 SOCKS5 关键错误
# ======================
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: lo
method: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
logoutput: /dev/null
EOF

# Web 面板
RUN cat > app.py << EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return '''
<h1>✅ Railway FRP 运行成功</h1>
<h3>客户端 A 配置文件</h3>
<textarea rows=10 cols=60>
[common]
server_addr = 你的Railway自动生成域名
server_port = 7000
token = railway_frp_123
</textarea>
<h3>SOCKS5 代理</h3>
<p>服务器：你的Railway自动生成域名</p>
<p>端口：10800</p>
'''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, threaded=True)
EOF

# 启动脚本
RUN cat > start.sh << EOF
#!/bin/sh
echo "启动 socks5..."
sockd -D &
sleep 1

echo "启动 frps..."
frps -c frps.ini &
sleep 2

echo "启动 frpc..."
frpc -c frpc.ini &
sleep 1

echo "启动 web..."
python3 app.py
EOF

RUN chmod +x start.sh
EXPOSE 7000 8080 10800
CMD ["/app/start.sh"]
