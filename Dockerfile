FROM alpine:latest
WORKDIR /app

# 安装所有依赖（修复：统一用RUN执行，无独立指令）
RUN apk add --no-cache wget python3 py3-pip dante-server \
    && pip3 install flask --no-cache-dir

# 安装 FRP 最新版
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.59.0/frp_0.59.0_linux_amd64.tar.gz \
    && tar -zxvf frp.tar.gz \
    && cd frp_* \
    && cp frps /usr/bin/ \
    && cp frpc /usr/bin/ \
    && chmod +x /usr/bin/frps /usr/bin/frpc

# 生成 FRP 服务端配置
RUN cat > /app/frps.ini << EOF
[common]
bind_port = 7000
token = frp_2025
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
EOF

# 生成 客户端B 配置（内置代理转发）
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

# 生成 SOCKS5 代理（客户端B 访问公网）
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: 0.0.0.0
method: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
logoutput: /var/log/sockd.log
EOF

# 生成 Web 管理面板（输出客户端A 配置）
RUN cat > /app/app.py << EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>FRP 统一代理网关</h1>
    <h2>流量链路：客户端A → FRP服务端 → 客户端B → 公网</h2>
    <hr>
    <h3>📄 客户端A 配置（直接复制）</h3>
    <textarea rows="10" cols="60">
[common]
server_addr = 你的服务器公网IP
server_port = 7000
token = frp_2025
    </textarea>
    <h3>🌐 客户端A 上网代理</h3>
    <p>SOCKS5 地址：你的服务器IP</p>
    <p>SOCKS5 端口：10800</p>
    <p>所有流量强制通过 客户端B 访问公网</p>
'''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

# 启动脚本（一键启动所有服务）
RUN cat > /app/start.sh << EOF
#!/bin/sh
echo "====================================="
echo " FRP 一体化代理服务启动中..."
echo "====================================="

# 启动客户端B的SOCKS5代理
sockd -D
# 启动FRP服务端
frps -c /app/frps.ini &
# 启动FRP客户端B
frpc -c /app/frpc.ini &
# 启动Web管理面板
python3 /app/app.py &

echo "====================================="
echo "✅ 启动成功！"
echo "🌐 Web面板：http://本机IP:8080"
echo "🔗 客户端A代理：服务器IP:10800 (SOCKS5)"
echo "📶 流量：A → 服务端 → B → 公网"
echo "====================================="

tail -f /dev/null
EOF

RUN chmod +x /app/start.sh

# 暴露端口
EXPOSE 7000 8080 10800 7500

# 启动命令
CMD ["/app/start.sh"]
