#!/bin/bash

# 颜色变量定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 检查是否为root用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用root用户运行此脚本！\n" && exit 1
# 打印带延迟的消息
print_with_delay() {
    local message="$1"
    local delay="$2"
    for (( i=0; i<${#message}; i++ )); do
        printf "%s" "${message:$i:1}"
        sleep "$delay"
    done
    echo ""
}
# 系统信息
SYSTEM_NAME=$(grep -i pretty_name /etc/os-release | cut -d \" -f2)
CORE_ARCH=$(arch)

# 介绍信息
show_banner() {
    clear
    cat << "EOF"
                       |\__/,|   (\\
                     _.|o o  |_   ) )
       -------------(((---(((-------------------
                    catmi.Hysteria 2 
       -----------------------------------------
EOF
    echo -e "${GREEN}System: ${PLAIN}${SYSTEM_NAME}"
    echo -e "${GREEN}Architecture: ${PLAIN}${CORE_ARCH}"
    echo -e "${GREEN}Version: ${PLAIN}1.0.0"
    echo -e "----------------------------------------"
}

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[Info]${PLAIN} $1"
}

print_error() {
    echo -e "${RED}[Error]${PLAIN} $1"
}

print_warning() {
    echo -e "${YELLOW}[Warning]${PLAIN} $1"
}

# 生成端口的函数
generate_port() {
    local protocol="$1"
    while :; do
        port=$((RANDOM % 10001 + 10000))
        read -p "请为 ${protocol} 输入监听端口(默认为随机生成): " user_input
        port=${user_input:-$port}
        ss -tuln | grep -q ":$port\b" || { echo "$port"; return 0; }
        echo "端口 $port 被占用，请输入其他端口"
    done
}

# 创建快捷方式
create_shortcut() {
    cat > /usr/local/bin/catmihy2 << 'EOF'
#!/bin/bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/cathy2.sh)
EOF
    chmod +x /usr/local/bin/catmihy2
    print_info "快捷方式 'catmihy2' 已创建，可使用 'catmihy2' 命令运行脚本"
}

# 安装 Hysteria 2
install_hysteria() {
    print_info "开始安装 Hysteria 2..."

    # 安装依赖
    if ! command -v jq &> /dev/null; then
        print_info "安装 jq..."
        apt-get update
        apt-get install -y jq
    fi

    if ! command -v vnstat &> /dev/null; then
        print_info "安装 vnstat..."
        apt-get update
        apt-get install -y vnstat
        systemctl start vnstat
        systemctl enable vnstat
        vnstat -u -i eth0  # 初始化 vnstat 数据库
    fi

    # 下载并安装 Hysteria 2
    if ! bash <(curl -fsSL https://get.hy2.sh/); then
        print_error "Hysteria 2 安装失败"
        return 1
    fi

   # 生成自签证书
print_with_delay "生成自签名证书..." 0.03
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
    -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" -days 36500 && \
    sudo chown hysteria /etc/hysteria/server.key && \
    sudo chown hysteria /etc/hysteria/server.crt
    # 生成随机密码
    AUTH_PASSWORD=$(openssl rand -base64 16)

    # 提示输入监听端口号
    PORT=$(generate_port "Hysteria")

    # 获取公网 IP 地址
    PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
    PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)
    echo "公网 IPv4 地址: $PUBLIC_IP_V4"
    echo "公网 IPv6 地址: $PUBLIC_IP_V6"

    # 选择使用哪个公网 IP 地址
    echo "请选择要使用的公网 IP 地址:"
    echo "1. $PUBLIC_IP_V4 (默认)"
    echo "2. $PUBLIC_IP_V6"
    echo "3. 自定义 IP"
    read -p "请输入对应的数字选择: " IP_CHOICE

    case "$IP_CHOICE" in
        1)
            PUBLIC_IP=$PUBLIC_IP_V4
            ;;
        2)
            PUBLIC_IP=$PUBLIC_IP_V6
            ;;
        3)
            read -p "请输入自定义的公网 IP 地址: " PUBLIC_IP
            ;;
        *)
            PUBLIC_IP=$PUBLIC_IP_V4
            ;;
    esac

    # 创建服务端配置
    create_server_config

    # 创建客户端配置
    create_client_config

    # 启动服务
    systemctl enable --now hysteria-server.service

    print_info "Hysteria 2 安装完成！"
    print_info "服务器地址：${PUBLIC_IP}"
    print_info "端口：${PORT}"
    print_info "密码：${AUTH_PASSWORD}"
    print_info "配置文件已保存到：/root/hy2/config.yaml"
}

# 创建服务端配置
create_server_config() {
  cat << EOF > /etc/hysteria/config.yaml
listen: ":$PORT"

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $AUTH_PASSWORD
  
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF
}

# 创建客户端配置
create_client_config() {
    mkdir -p /root/hy2
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
    server: $PUBLIC_IP
    port: $PORT
    type: hysteria2
    up: "45 Mbps"
    down: "150 Mbps"
    sni: bing.com
    password: $AUTH_PASSWORD
    skip-cert-verify: true
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
}

# 卸载 Hysteria 2
uninstall_hysteria() {
    print_info "开始卸载 Hysteria 2..."
    systemctl stop hysteria-server.service
    systemctl disable hysteria-server.service
    rm -rf /etc/hysteria
    rm -rf /root/hy2
    rm -f /usr/local/bin/catmihy2
    systemctl daemon-reload
    print_info "Hysteria 2 已成功卸载"
}

# 更新 Hysteria 2
update_hysteria() {
    print_info "开始更新 Hysteria 2..."
    if ! bash <(curl -fsSL https://get.hy2.sh/); then
        print_error "更新失败"
        return 1
    fi
    print_info "更新成功"
    systemctl restart hysteria-server.service
}

# 查看客户端配置
view_client_config() {
    if [ -f "/root/hy2/config.yaml" ]; then
        cat /root/hy2/config.yaml
    else
        print_error "客户端配置文件不存在"
    fi
}

# 修改配置
modify_config() {
    read -p "请输入新的端口号 (默认随机生成): " new_port
    new_port=${new_port:-$(generate_port "Hysteria")}

    read -p "请输入新的密码 (默认随机生成): " new_password
    new_password=${new_password:-$(openssl rand -base64 16)}

    sed -i "s/^listen: :[0-9]*$/listen: :${new_port}/" /etc/hysteria/config.yaml
    sed -i "s/^password: .*/password: ${new_password}/" /etc/hysteria/config.yaml

    sed -i "s/^port: [0-9]*$/port: ${new_port}/" /root/hy2/config.yaml
    sed -i "s/^password: .*/password: ${new_password}/" /root/hy2/config.yaml

    print_info "配置已修改为："
    print_info "端口：${new_port}"
    print_info "密码：${new_password}"
    systemctl restart hysteria-server.service
}

# 主菜单
show_menu() {
    clear
    # 获取服务状态
    hysteria_server_status=$(systemctl is-active hysteria-server.service)
    hysteria_server_status_text=$(if [[ "$hysteria_server_status" == "active" ]]; then echo -e "${GREEN}启动${PLAIN}"; else echo -e "${RED}未启动${PLAIN}"; fi)
    
    # 显示菜单
    print_with_delay "**************Hysteria 2.catmi*************" 0.03
    echo -e "
  ${GREEN}Hysteria 2 管理脚本${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 安装 Hysteria 2
  ${GREEN}2.${PLAIN} 卸载 Hysteria 2
  ${GREEN}3.${PLAIN} 更新 Hysteria 2
  ${GREEN}4.${PLAIN} 重启 Hysteria 2
  ${GREEN}5.${PLAIN} 查看客户端配置
  ${GREEN}6.${PLAIN} 修改配置
  ${GREEN}0.${PLAIN} 退出脚本
  ----------------------
  Hysteria 2 服务状态: ${hysteria_server_status_text}
  ----------------------"
  
    read -p "请输入选项 [0-6]: " choice
    
    case "${choice}" in
        0) exit 0 ;;
        1) install_hysteria ;;
        2) uninstall_hysteria ;;
        3) update_hysteria ;;
        4) systemctl restart hysteria-server.service ;;
        5) view_client_config ;;
        6) modify_config ;;
        *) echo -e "${RED}无效的选项 ${choice}${PLAIN}" ;;
    esac

    echo && read -p "按回车键继续..." && echo
}

# 主程序
main() {
    show_banner
    create_shortcut
    while true; do
        show_menu
    done
}

main "$@"
