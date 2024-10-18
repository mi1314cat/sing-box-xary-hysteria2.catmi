#!/bin/bash

# 颜色变量定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 检查是否为root用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用root用户运行此脚本！\n" && exit 1

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
    local min_port=10000
    local max_port=65535
    local max_retries=10
    local retries=0
    
    while [[ $retries -lt $max_retries ]]; do
        local port=$(shuf -i ${min_port}-${max_port} -n 1)
        if ! ss -tuln | grep -q ":${port}\b"; then
            echo "${port}"
            return 0
        fi
        ((retries++))
    done
    
    print_error "无法找到可用端口，已达到最大重试次数"
    exit 1
}

# 创建快捷方式
create_shortcut() {
    cat > /usr/local/bin/catmi << 'EOF'
#!/bin/bash
bash <(curl -fsSL https://raw.githubusercontent.com/你的GitHub用户名/hysteria2-script/main/install.sh)
EOF
    chmod +x /usr/local/bin/catmi
    print_info "快捷方式 'catmi' 已创建，现在可以直接使用 'catmi' 命令运行脚本"
}

# 安装基础依赖
install_base() {
    if [[ -f /etc/debian_version ]]; then
        apt update -y
        apt install -y curl wget tar openssl nano
        if [[ $? -ne 0 ]]; then
            print_error "基础依赖安装失败"
            exit 1
        fi
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y curl wget tar openssl nano
        if [[ $? -ne 0 ]]; then
            print_error "基础依赖安装失败"
            exit 1
        fi
    fi
}

# 安装 Hysteria 2
install_hysteria() {
    print_info "开始安装 Hysteria 2..."
    
    # 安装基础依赖
    install_base
    
    # 下载并安装 Hysteria 2
    bash <(curl -fsSL https://get.hy2.sh/)
    if [[ $? -ne 0 ]]; then
        print_error "Hysteria 2 安装失败"
        exit 1
    fi
    
    # 生成自签证书
    print_info "生成自签名证书..."
    mkdir -p /etc/hysteria
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -subj "/CN=bing.com" -days 36500
    
    chmod 644 /etc/hysteria/server.crt
    chmod 644 /etc/hysteria/server.key
    
    # 生成随机密码
    AUTH_PASSWORD=$(openssl rand -base64 16)
    
    # 获取监听端口
    PORT=$(generate_port)
    
    # 获取公网IP
    IP=$(get_public_ip)
    
    # 创建服务端配置
    create_server_config
    
    # 创建客户端配置
    create_client_config
    
    # 启动服务
    systemctl enable --now hysteria-server.service
    
    print_info "Hysteria 2 安装完成！"
    print_info "服务器地址：${IP}"
    print_info "端口：${PORT}"
    print_info "密码：${AUTH_PASSWORD}"
    print_info "配置文件已保存到：/root/hy2/config.yaml"
}

# 创建服务端配置
create_server_config() {
    cat > /etc/hysteria/config.yaml << EOF
listen: :${PORT}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${AUTH_PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

bandwidth:
  up: 1 gbps
  down: 1 gbps
EOF
}

# 创建客户端配置
create_client_config() {
    mkdir -p /root/hy2
    cat > /root/hy2/config.yaml << EOF
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
  - name: Hy2-${IP}
    server: ${IP}
    port: ${PORT}
    type: hysteria2
    up: "100 Mbps"
    down: "100 Mbps"
    sni: bing.com
    password: ${AUTH_PASSWORD}
    skip-cert-verify: true
    alpn:
      - h3

proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
      - Hy2-${IP}
      - DIRECT

  - name: 自动选择
    type: url-test
    proxies:
      - Hy2-${IP}
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50

rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,节点选择
EOF
}

# 获取公网IP
get_public_ip() {
    local ipv4=$(curl -s4m8 ip.gs)
    local ipv6=$(curl -s6m8 ip.gs)
    
    if [[ -z "${ipv4}" && -z "${ipv6}" ]]; then
        print_error "未能获取到公网IP地址"
        exit 1
    fi
    
    if [[ -n "${ipv4}" && -n "${ipv6}" ]]; then
        print_info "检测到 IPv4 和 IPv6 地址"
        echo -e "1. IPv4: ${ipv4}"
        echo -e "2. IPv6: ${ipv6}"
        while true; do
            read -p "请选择使用的IP类型 [1-2]: " ip_type
            if [[ "${ip_type}" == "1" ]]; then
                echo "${ipv4}"
                return 0
            elif [[ "${ip_type}" == "2" ]]; then
                echo "${ipv6}"
                return 0
            else
                print_error "无效的选择，请重试"
            fi
        done
    elif [[ -n "${ipv4}" ]]; then
        echo "${ipv4}"
    elif [[ -n "${ipv6}" ]]; then
        echo "${ipv6}"
    fi
}

# 流量监控脚本 - traffic_monitor.sh
create_traffic_monitor() {
    cat > /usr/local/bin/hy2_traffic_monitor.sh << 'EOF'
#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

# 配置文件路径
TRAFFIC_CONFIG="/etc/hysteria/traffic_config"
LOG_FILE="/var/log/hysteria/traffic.log"

# 确保日志目录存在
mkdir -p /var/log/hysteria

# 读取配置
if [ -f "$TRAFFIC_CONFIG" ]; then
    source $TRAFFIC_CONFIG
else
    echo "TRAFFIC_LIMIT=1000" > $TRAFFIC_CONFIG  # 默认1000GB
    source $TRAFFIC_CONFIG
fi

# 获取当前流量
get_traffic() {
    # 使用 hysteria 命令获取实时流量统计
    local current_stats=$(hysteria stats 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "0 0"
        return
    }
    
    # 提取上传和下载流量(转换为GB)
    local upload=$(echo "$current_stats" | grep "Upload" | awk '{print $2}' | numfmt --from=iec)
    local download=$(echo "$current_stats" | grep "Download" | awk '{print $2}' | numfmt --from=iec)
    
    upload_gb=$(echo "scale=2; $upload/1024/1024/1024" | bc)
    download_gb=$(echo "scale=2; $download/1024/1024/1024" | bc)
    
    echo "$upload_gb $download_gb"
}

# 检查流量并记录
check_traffic() {
    read up_gb down_gb <<< $(get_traffic)
    total_gb=$(echo "$up_gb + $down_gb" | bc)
    
    # 记录流量
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Upload: ${up_gb}GB, Download: ${down_gb}GB, Total: ${total_gb}GB" >> $LOG_FILE
    
    # 检查是否超过限制
    if (( $(echo "$total_gb > $TRAFFIC_LIMIT" | bc -l) )); then
        echo -e "${RED}流量超过限制 ${TRAFFIC_LIMIT}GB，正在停止服务...${PLAIN}"
        systemctl stop hysteria-server.service
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Traffic limit exceeded. Service stopped." >> $LOG_FILE
        exit 1
    fi
}

# 主循环
while true; do
    check_traffic
    sleep 60  # 每分钟检查一次
done
EOF

    chmod +x /usr/local/bin/hy2_traffic_monitor.sh
    
    # 创建系统服务
    cat > /etc/systemd/system/hy2-traffic-monitor.service << 'EOF'
[Unit]
Description=Hysteria 2 Traffic Monitor
After=hysteria-server.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hy2_traffic_monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable hy2-traffic-monitor.service
    systemctl start hy2-traffic-monitor.service
}

# 在主脚本中添加流量管理函数
traffic_management() {
    while true; do
        echo -e "
  ${GREEN}流量管理${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 设置流量限制
  ${GREEN}2.${PLAIN} 查看当前流量
  ${GREEN}3.${PLAIN} 查看流量日志
  ${GREEN}4.${PLAIN} 重置流量统计
  ${GREEN}0.${PLAIN} 返回主菜单
  ----------------------"
        
        read -p "请输入选项 [0-4]: " choice
        case "${choice}" in
            0) break ;;
            1) 
                read -p "请输入流量限制(GB): " new_limit
                if [[ "$new_limit" =~ ^[0-9]+$ ]]; then
                    echo "TRAFFIC_LIMIT=$new_limit" > /etc/hysteria/traffic_config
                    echo -e "${GREEN}流量限制已设置为 ${new_limit}GB${PLAIN}"
                    systemctl restart hy2-traffic-monitor.service
                else
                    echo -e "${RED}无效的输入！${PLAIN}"
                fi
                ;;
            2)
                read up_gb down_gb <<< $(get_traffic)
                total_gb=$(echo "$up_gb + $down_gb" | bc)
                limit=$(cat /etc/hysteria/traffic_config | grep TRAFFIC_LIMIT | cut -d= -f2)
                echo -e "
当前流量统计:
------------------------
上传流量: ${GREEN}${up_gb}GB${PLAIN}
下载流量: ${GREEN}${down_gb}GB${PLAIN}
总流量: ${GREEN}${total_gb}GB${PLAIN}
流量限制: ${YELLOW}${limit}GB${PLAIN}
------------------------"
                ;;
            3)
                if [ -f "/var/log/hysteria/traffic.log" ]; then
                    tail -n 50 /var/log/hysteria/traffic.log
                else
                    echo -e "${YELLOW}暂无流量日志${PLAIN}"
                fi
                ;;
            4)
                systemctl restart hysteria-server.service
                systemctl restart hy2-traffic-monitor.service
                echo -e "${GREEN}流量统计已重置${PLAIN}"
                ;;
            *) echo -e "${RED}无效的选项 ${choice}${PLAIN}" ;;
        esac
        echo && read -p "按回车键继续..." && echo
    done
}

# 卸载 Hysteria 2
uninstall_hysteria() {
    print_info "开始卸载 Hysteria 2..."
    systemctl stop hysteria-server.service
    systemctl disable hysteria-server.service
    rm -rf /etc/hysteria
    rm -rf /root/hy2
    rm -f /usr/local/bin/catmi
    print_info "Hysteria 2 已成功卸载"
}

# 更新 Hysteria 2
update_hysteria() {
    print_info "开始更新 Hysteria 2..."
    bash <(curl -fsSL https://get.hy2.sh/)
    if [[ $? -ne 0 ]]; then
        print_error "更新失败"
        return 1
    fi
    print_info "更新成功"
    systemctl restart hysteria-server.service
}

# 更新后的显示主菜单函数
show_menu() {
    echo -e "
  ${GREEN}Hysteria 2 管理脚本${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 安装 Hysteria 2
  ${GREEN}2.${PLAIN} 卸载 Hysteria 2
  ${GREEN}3.${PLAIN} 更新 Hysteria 2
  ${GREEN}4.${PLAIN} 重启 Hysteria 2
  ${GREEN}5.${PLAIN} 查看配置
  ${GREEN}6.${PLAIN} 修改配置
  ${GREEN}7.${PLAIN} 流量管理
  ${GREEN}0.${PLAIN} 退出脚本
  ----------------------"
    read -p "请输入选项 [0-7]: " choice
    
    case "${choice}" in
        0) exit 0 ;;
        1) install_hysteria ;;
        2) uninstall_hysteria ;;
        3) update_hysteria ;;
        4) systemctl restart hysteria-server.service ;;
        5) cat /etc/hysteria/config.yaml ;;
        6) nano /etc/hysteria/config.yaml ;;
        7) traffic_management ;;
        *) print_error "无效的选项 ${choice}" ;;
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
