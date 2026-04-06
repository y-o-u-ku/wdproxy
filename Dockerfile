FROM alpine:latest
WORKDIR /app

# 安装所有依赖：frp、socks5、python、web面板
RUN apk add --no-cache wget python3 py3-pip dante-server && \\
    pip3 install flask --no-cache-dir

# 安装最新版 FRP
RUN wget -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.58.0/frp_0.58.0_linux_amd64.tar.gz && \\
    tar -zxvf frp.tar.gz && cd frp_* && \\
    cp frps /usr/bin/ && cp frpc /usr/bin/ && chmod +x /usr/bin/frp*

# ======================================
# 自动生成 frp 服务端配置
# ======================================
RUN cat > /app/frps.ini << EOF
[common]
bind_port = 7000
token = my-frp-123456
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
EOF

# ======================================
# 自动生成 客户端B 配置（内置代理）
# ======================================
RUN cat > /app/frpc.ini << EOF
[common]
server_addr = 127.0.0.1
server_port = 7000
token = my-frp-123456

[socks5]
type = tcp
local_ip = 127.0.0.1
local_port = 1080
remote_port = 10800
EOF

# ======================================
# 自动生成 SOCKS5 代理配置（客户端B）
# ======================================
RUN cat > /etc/sockd.conf << EOF
internal: 127.0.0.1 port = 1080
external: 0.0.0.0
method: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
logoutput: /var/log/sockd.log
EOF

# ======================================
# 自动生成 Web 管理面板（输出A配置）
# ======================================
RUN cat > /app/app.py << EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>FRP 统一代理管理（A→服务端→B→公网）</h1>
    <h3>客户端 A 配置（直接复制）</h3>
    <textarea rows=10 cols=60>
[common]
server_addr = 你的服务器公网IP
server_port = 7000
token = my-frp-123456
    </textarea>
    <h3>客户端A 代理上网设置</h3>
    <p>SOCKS5 地址：你的服务器IP</p>
    <p>SOCKS5 端口：10800</p>
    <p>所有流量 → 客户端B 访问公网</p>
    '''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

# ======================================
# 自动生成启动脚本
# ======================================
RUN cat > /app/run.sh << EOF
#!/bin/sh
sockd -D &
frps -c /app/frps.ini &
frpc -c /app/frpc.ini &
python3 /app/app.py &

echo "====================================="
echo " 服务启动成功！"
echo " Web 面板：http://本机IP:8080"
echo " 客户端A 代理：IP:10800 (SOCKS5)"
echo " 流量链路：A → 服务端 → B → 公网"
echo "====================================="

tail -f /dev/null
EOF

RUN chmod +x /app/run.sh

# 暴露端口
EXPOSE 7000 8080 10800 7500

# 启动
CMD ["/app/run.sh"]
