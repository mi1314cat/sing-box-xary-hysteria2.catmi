#!/bin/bash

# 启用错误处理，如果任何命令失败，脚本将退出
set -e

# 介绍信息
echo -e "\e[92m"
echo -e "                       |\\__/,|   (\\\\ \n"
echo -e "                     _.|o o  |_   ) )\n"
echo -e "       -------------(((---(((-------------------\n"
echo -e "                    catmi.Hysteria 2 \n"
echo -e "       -----------------------------------------\n"
echo -e "\e[0m"

# 打印带延迟的消息
print_with_delay() {
    local message="$1"
    local delay="$2"
    for (( i=0; i<${#message}; i++ )); do
        echo -n "${message:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# 生成端口的函数
generate_port() {
    local protocol="$1"
    local port
    while true; do
        port=$((RANDOM % 10001 + 10000))
        read -p "请为 ${protocol} 输入监听端口(默认为随机生成): " user_input
        port=${user_input:-$port}
        if ! ss -tuln | grep -q ":$port\b"; then
            echo "$port"
            return $port
        else
            echo "端口 $port 被占用，请输入其他端口"
        fi
    done
}

# 定义函数，返回随机选择的域名
random_website() {
    local domains=(
        "bing.com"
        "one-piece.com"
        "lovelive-anime.jp"
        "swift.com"
        "academy.nvidia.com"
        "cisco.com"
        "samsung.com"
        "amd.com"
        "apple.com"
        "music.apple.com"
        "amazon.com"
        "fandom.com"
        "tidal.com"
        "zoro.to"
        "pixiv.co.jp"
        "mxj.myanimelist.net"
        "mora.jp"
        "j-wave.co.jp"
        "dmm.com"
        "booth.pm"
        "ivi.tv"
        "leercapitulo.com"
        "sky.com"
        "itunes.apple.com"
        "download-installer.cdn.mozilla.net"
        "images-na.ssl-images-amazon.com"
        "swdist.apple.com"
        "swcdn.apple.com"
        "updates.cdn-apple.com"
        "mensura.cdn-apple.com"
        "osxapps.itunes.apple.com"
        "aod.itunes.apple.com"
        "www.google-analytics.com"
        "dl.google.com"
    )

    local total_domains=${#domains[@]}
    local random_index=$((RANDOM % total_domains))
    
    # 输出选择的域名
    echo "${domains[random_index]}"
}

print_with_delay "**************Hysteria 2.catmi*************" 0.03
# 自动安装 Hysteria 2
print_with_delay "正在安装 Hysteria 2..." 0.03
bash <(curl -fsSL https://get.hy2.sh/)

# 调用函数获取随机域名
domain=$(random_website)

# 生成自签证书
print_with_delay "生成自签名证书..." 0.03
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
    -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
    -subj "/CN=$domain" -days 36500 && \
    sudo chown hysteria /etc/hysteria/server.key && \
    sudo chown hysteria /etc/hysteria/server.crt

# 确保密钥和证书仅对 Hysteria 用户可读
chmod 600 /etc/hysteria/server.key /etc/hysteria/server.crt

# 自动生成密码
hysteria_auth_password=$(openssl rand -base64 16)

# 提示输入监听端口号
hysteria_port=$(generate_port "Hysteria")

# 获取公网 IP 地址
public_ip_v4=$(curl -s https://api.ipify.org)
public_ip_v6=$(curl -s https://api64.ipify.org)
echo "公网 IPv4 地址: $public_ip_v4"
echo "公网 IPv6 地址: $public_ip_v6"

# 选择使用哪个公网 IP 地址
echo "请选择要使用的公网 IP 地址:"
echo "1. $public_ip_v4"
echo "2. $public_ip_v6"
read -p "请输入对应的数字选择: " ip_choice

if [ "$ip_choice" -eq 1 ]; then
    public_ip=$public_ip_v4
elif [ "$ip_choice" -eq 2 ]; then
    public_ip=$public_ip_v6
else
    echo "无效选择，退出脚本"
    exit 1
fi

# 创建 Hysteria 2 服务端配置文件
print_with_delay "生成 Hysteria 2 配置文件..." 0.03
cat << EOF > /etc/hysteria/config.yaml
listen: ":$hysteria_port"

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $hysteria_auth_password
  
masquerade:
  type: proxy
  proxy:
    url: https://$domain
    rewriteHost: true
EOF

# 重启 Hysteria 服务以应用配置
print_with_delay "重启 Hysteria 服务以应用新配置..." 0.03
systemctl restart hysteria-server.service

# 启动并启用 Hysteria 服务
print_with_delay "启动 Hysteria 服务..." 0.03
systemctl enable hysteria-server.service

# 创建客户端配置文件目录
mkdir -p /root/hy2

# 生成客户端配置文件
print_with_delay "生成客户端配置文件..." 0.03
cat << EOF > /root/hy2/config.yaml
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
ipv6: true

dns:
  enable: true
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:        
  - name: Hy2-Hysteria2
    server: $public_ip
    port: $hysteria_port
    type: hysteria2
    up: "45 Mbps"
    down: "150 Mbps"
    sni: $domain
    password: $hysteria_auth_password
    skip-cert-verify: false
    alpn:
      - h3

proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
      - Hy2-Hysteria2
      - DIRECT

  - name: 自动选择
    type: url-test
    proxies:
      - Hy2-Hysteria2
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50

rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,节点选择
EOF

# 显示生成的密码
print_with_delay "Hysteria 2 安装和配置完成！" 0.03
print_with_delay "认证密码: $hysteria_auth_password" 0.03
print_with_delay "伪装域名：$domain" 0.03
print_with_delay "服务端配置文件已保存到 /etc/hysteria/config.yaml" 0.03
print_with_delay "客户端配置文件已保存到 /root/hy2/config.yaml" 0.03

# 显示 Hysteria 服务状态
systemctl status hysteria-server.service
print_with_delay "**************Hysteria 2.catmi.客户端配置*************" 0.03
cat /root/hy2/config.yaml
print_with_delay "**************Hysteria 2.catmi.end*************" 0.03
