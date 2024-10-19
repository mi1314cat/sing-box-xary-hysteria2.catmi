#!/bin/bash

# 介绍信息
printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                   catmi-alpine-Hysteria 2 \n"
printf "       -----------------------------------------\n"
printf "\e[0m"

# 安装必要的软件包
apk add --no-cache wget curl git openssh openssl openrc

# 生成随机密码
generate_random_password() {
  openssl rand -base64 18
}

# 生成未被占用的端口
generate_port() {
  local protocol="$1"
  while :; do
    local port=$((RANDOM % 10001 + 10000))
    read -p "请为 ${protocol} 输入监听端口(默认为随机生成 ${port}): " user_input
    port=${user_input:-$port}
    if ! ss -tuln | grep -q ":$port\b"; then
      echo "$port"
      return
    fi
    echo "端口 $port 被占用，请输入其他端口"
  done
}

# 创建客户端配置
create_client_config() {
  mkdir -p /root/hy2
  cat << EOF > /root/hy2/config.yaml
- name: Hy2-Hysteria2
  server: $PUBLIC_IP
  port: $LISTEN_PORT
  type: hysteria2
  up: "45 Mbps"
  down: "150 Mbps"
  sni: bing.com
  password: $GENPASS
  skip-cert-verify: true
  alpn:
    - h3
EOF
}

# 生成随机密码
GENPASS=$(generate_random_password)

# 生成监听端口
LISTEN_PORT=$(generate_port "Hysteria")

# 获取公共 IP
PUBLIC_IP=$(curl -s ifconfig.me)

# 生成 Hysteria 配置文件内容
echo_hysteria_config_yaml() {
  cat << EOF
listen: :$LISTEN_PORT

# 有域名，使用CA证书
#acme:
#  domains:
#    - test.heybro.bid # 你的域名，需要先解析到服务器ip
#  email: xxx@gmail.com

# 使用自签名证书
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $GENPASS

masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF
}

# 生成 Hysteria 自启动脚本
echo_hysteria_autoStart() {
  cat << EOF
#!/sbin/openrc-run

name="hysteria"

command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"

pidfile="/var/run/${name}.pid"

command_background="yes"

depend() {
  need networking
}
EOF
}

# 获取系统架构
ARCH=$(uname -m)

# 下载 Hysteria
if [ "$ARCH" = "aarch64" ]; then
  wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-arm64 --no-check-certificate
else
  wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate
fi

# 检查下载是否成功
if [ $? -ne 0 ]; then
  echo "下载 Hysteria 失败"
  exit 1
fi

# 确保文件有执行权限
chmod +x /usr/local/bin/hysteria

# 创建 Hysteria 配置目录
mkdir -p /etc/hysteria/

# 生成自签名证书
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500
if [ $? -ne 0 ]; then
  echo "生成自签名证书失败"
  exit 1
fi

# 写配置文件
echo_hysteria_config_yaml > "/etc/hysteria/config.yaml"
if [ $? -ne 0 ]; then
  echo "写入 Hysteria 配置文件失败"
  exit 1
fi

# 写自启动脚本
echo_hysteria_autoStart > "/etc/init.d/hysteria"
if [ $? -ne 0 ]; then
  echo "写入 Hysteria 自启动脚本失败"
  exit 1
fi
chmod +x /etc/init.d/hysteria

# 启用自启动
rc-update add hysteria
if [ $? -ne 0 ]; then
  echo "启用 Hysteria 自启动失败"
  exit 1
fi

# 启动服务
service hysteria start
if [ $? -ne 0 ]; then
  echo "启动 Hysteria 服务失败"
  exit 1
fi

# 显示 Hysteria 服务运行状态
echo "Hysteria 服务运行状态:"
service hysteria status

# 创建客户端配置
create_client_config
if [ $? -ne 0 ]; then
  echo "创建客户端配置文件失败"
  exit 1
fi

# 显示客户端配置文件内容
echo "客户端配置文件内容:"
cat /root/hy2/config.yaml

echo "------------------------------------------------------------------------"
echo "Hysteria2 已经安装完成"
echo "默认端口： $LISTEN_PORT ， 密码为： $GENPASS ，工具中配置：tls，SNI为： bing.com"
echo "配置文件：/etc/hysteria/config.yaml"
echo "已经随系统自动启动"
echo "查看状态： service hysteria status"
echo "重启服务： service hysteria restart"
echo "请享用。"
echo "------------------------------------------------------------------------"

echo "Hysteria 配置完成，服务已启动"
