#!/bin/bash

# 颜色变量
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 检查是否以root身份运行
if [ $EUID -ne 0 ]; then
    echo -e "${RED}错误: ${PLAIN} 必须以root身份运行!"
    exit 1
fi

# 系统信息
SYSTEM_NAME=$(grep -i pretty_name /etc/os-release | cut -d \" -f2)
CORE_ARCH=$(arch)

# 横幅
show_banner() {
    clear
    cat << "EOF"
                       |\__/,|   (\\
                     _.|o o  |_   ) )
       -------------(((---(((-------------------
                    catmi.Hysteria 2 
EOF
    echo -e "${GREEN}系统: ${PLAIN}${SYSTEM_NAME}"
    echo -e "${GREEN}架构: ${PLAIN}${CORE_ARCH}"
    echo -e "${GREEN}版本: ${PLAIN}1.0.0"
    echo -e "----------------------------------------"
}
# 生成随机端口
generate_port() {
    local protocol="$1"
    while :; do
        port=$((RANDOM % 10001 + 10000))
        read -p "请为 ${protocol} 输入监听端口(默认为随机生成): " user_input
        port=${user_input:-$port}
        ss -tuln | grep -q ":$port\b" || { echo "$port"; return $port; }
        echo "端口 $port 被占用，请输入其他端口"
    done
}


# 彩色消息
print_info() {
    echo -e "${GREEN}[信息]${PLAIN} $1"
}

print_error() {
    echo -e "${RED}[错误]${PLAIN} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${PLAIN} $1"
}
# 创建快捷方式
create_shortcut() {
    cat > /usr/local/bin/catmihy2 << 'EOF'
#!/bin/bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/cathy2.sh)
EOF
    chmod +x /usr/local/bin/catmihy2
    print_info "快捷方式 'catmihy2' 创建。使用 'catmihy2' 直接运行此脚本。"
}
# 安装 Hysteria 2
install_hysteria() {
    print_info "安装 Hysteria 2..."

    # 下载并安装 Hysteria 2
    bash <(curl -fsSL https://get.hy2.sh/)
    if [ $? -ne 0 ]; then
        print_error "Hysteria 2 安装失败。"
        exit 1
    fi

    print_info "生成自签名证书..."
    mkdir -p /etc/hysteria
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -subj "/CN=bing.com" -days 36500

    chmod 644 /etc/hysteria/server.crt
    chmod 644 /etc/hysteria/server.key

    AUTH_PASSWORD=$(openssl rand -base64 16)
    # 提示输入监听端口号
    PORT=$(generate_port "Hysteria")  # 添加缺失的闭合括号
    
    # 获取公网 IP 地址
    PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
    PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)

    echo "公网 IPv4 地址: $PUBLIC_IP_V4"
    echo "公网 IPv6 地址: $PUBLIC_IP_V6"
    echo "请选择要使用的公网 IP 地址:"
    echo "1. $PUBLIC_IP_V4"
    echo "2. $PUBLIC_IP_V6"
    
    read -p "请输入对应的数字选择: " IP_CHOICE

    if [ "$IP_CHOICE" -eq 1 ]; then
        PUBLIC_IP=$PUBLIC_IP_V4
    elif [ "$IP_CHOICE" -eq 2 ]; then
        PUBLIC_IP=$PUBLIC_IP_V6
    else
        print_error "无效选择，退出脚本"
        exit 1
    fi

    create_server_config
    create_client_config
    
    # 启动服务
    systemctl enable --now hysteria-server.service
    if [ $? -ne 0 ]; then
        print_error "服务启动失败，请检查错误日志。"
        exit 1
    fi

    # 检查服务状态
    if ! systemctl is-active --quiet hysteria-server.service; then
        print_error "Hysteria 2 服务未能成功启动。"
        exit 1
    fi

    create_traffic_monitor

    print_info "Hysteria 2 安装完成!"
    print_info "服务器地址: ${PUBLIC_IP}"
    print_info "端口: ${PORT}"
    print_info "密码: ${AUTH_PASSWORD}"
    print_info "客户端配置保存至: /root/hy2/config.yaml"

    print_info "返回主菜单..."
    show_menu  # 确保返回主菜单
}


# 创建服务器配置
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
    up: "45 Mbps"
    down: "150 Mbps"
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



# 创建流量监控
create_traffic_monitor() {
    cat > /usr/local/bin/hy2_traffic_monitor.sh << 'EOF'
#!/bin/bash

# 颜色变量
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
    echo "TRAFFIC_LIMIT=1000" > $TRAFFIC_CONFIG  # 默认 1000GB
    echo "TRAFFIC_MANAGEMENT_ENABLED=false" >> $TRAFFIC_CONFIG  # 默认禁用
    echo "TRAFFIC_RESET_MODE=monthly" >> $TRAFFIC_CONFIG  # 默认每月重置
    source $TRAFFIC_CONFIG
fi


# 获取当前流量

# 获取流量信息
get_traffic_info() {
    echo "调试: 正在获取流量信息..."
    if systemctl is-active --quiet hysteria-server.service; then
        echo "调试: hysteria-server.service 已启用"
        read up_gb down_gb <<< $(/usr/local/bin/hy2_traffic_monitor.sh get_traffic 2>/dev/null)
        echo "调试: 读取流量信息: up_gb=${up_gb}, down_gb=${down_gb}"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}获取流量信息失败！${PLAIN}"
            up_gb="0"
            down_gb="0"
        fi
        
        total_gb=$(echo "$up_gb + $down_gb" | bc)
        echo "调试: 上行流量: ${up_gb}GB, 下行流量: ${down_gb}GB, 总流量: ${total_gb}GB"
    else
        up_gb="0"
        down_gb="0"
        total_gb="0"
        echo "调试: Hysteria 服务器未启用，流量设置为0"
    fi

    echo "调试: 正在获取流量限制..."
    limit=$(grep TRAFFIC_LIMIT /etc/hysteria/traffic_config | cut -d= -f2)
    if [ -z "$limit" ]; then
        echo -e "${RED}流量限制未找到！${PLAIN}"
        limit="0"
    fi

    remaining_gb=$(echo "$limit - $total_gb" | bc)
    echo "调试: 流量限制: ${limit}GB, 剩余流量: ${remaining_gb}GB"

    echo -e "流量监控信息:\n上行流量: ${up_gb}GB\n下行流量: ${down_gb}GB\n总流量: ${total_gb}GB\n流量限制: ${limit}GB\n剩余流量: ${remaining_gb}GB"
}
# 检查流量并记录
check_traffic() {
    read up_gb down_gb <<< $(get_traffic)
    total_gb=$(echo "$up_gb + $down_gb" | bc)
    
    # 记录流量
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 上传: ${up_gb}GB, 下载: ${down_gb}GB, 总计: ${total_gb}GB" >> $LOG_FILE
    
    # 检查是否超过限制
    if [ "$TRAFFIC_MANAGEMENT_ENABLED" == "true" ] && (( $(echo "$total_gb > $TRAFFIC_LIMIT" | bc -l) )); then
        echo -e "${RED}流量限制超出 ${TRAFFIC_LIMIT}GB。停止服务...${PLAIN}"
        systemctl stop hysteria-server.service
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 流量限制超出。服务已停止。" >> $LOG_FILE
        exit 1
    fi
}

# 重置流量统计
reset_traffic() {
    systemctl restart hysteria-server.service
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 流量统计重置。" >> $LOG_FILE
    echo -e "${GREEN}流量统计重置。${PLAIN}"
}

# 检查是否需要重置流量
check_reset() {
    if [ "$TRAFFIC_MANAGEMENT_ENABLED" == "true" ]; then
        if [ "$TRAFFIC_RESET_MODE" == "monthly" ]; then
            if [ $(date +%d) -eq 1 ]; then
                reset_traffic
            fi
        elif [ "$TRAFFIC_RESET_MODE" == "30days" ]; then
            if [ $(date +%s) -ge $(($(date +%s) - 2592000)) ]; then
                reset_traffic
            fi
        fi
    fi
}

# 主循环
while true; do
    check_reset
    check_traffic
    sleep 60  # 每分钟检查一次
done
EOF

    chmod +x /usr/local/bin/hy2_traffic_monitor.sh
    
    # 创建系统服务
    cat > /etc/systemd/system/hy2-traffic-monitor.service << 'EOF'
[Unit]
Description=Hysteria 2 流量监控
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
    systemctl stop hy2-traffic-monitor.service  # 默认禁用
}



# 流量管理
traffic_management() {
    while true; do
        echo "调试: 正在获取流量监控服务状态..."
        hy2_traffic_monitor_status=$(systemctl is-active hy2-traffic-monitor.service)
        
        if [ "${hy2_traffic_monitor_status}" == "active" ]; then
            hy2_traffic_monitor_status_text="${GREEN}已启用${PLAIN}"
        else
            hy2_traffic_monitor_status_text="${RED}已禁用${PLAIN}"
        fi
        echo "调试: 流量监控服务状态: ${hy2_traffic_monitor_status_text}"

        # 调用获取流量信息的函数
        get_traffic_info

        echo -e "
  ${GREEN}流量管理${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 设置流量限制
  ${GREEN}2.${PLAIN} 查看当前流量
  ${GREEN}3.${PLAIN} 查看流量日志
  ${GREEN}4.${PLAIN} 重置流量统计
  ${GREEN}5.${PLAIN} 启用/禁用流量管理
  ${GREEN}6.${PLAIN} 设置流量重置模式
  ${GREEN}0.${PLAIN} 返回主菜单
  ----------------------
  流量管理服务状态: ${hy2_traffic_monitor_status_text}
  流量限制: ${limit}GB
  已用流量: ${total_gb}GB
  剩余流量: ${remaining_gb}GB
  ----------------------"

        read -p "输入选项 [0-6]: " choice
        echo "选择的选项: ${choice}"  # 调试信息
        
        case "${choice}" in
            0) break ;;
            1) 
                read -p "输入流量限制 (GB): " new_limit
                if [[ "$new_limit" =~ ^[0-9]+$ ]]; then
                    sed -i "s/^TRAFFIC_LIMIT=.*/TRAFFIC_LIMIT=$new_limit/" /etc/hysteria/traffic_config
                    echo -e "${GREEN}流量限制设置为 ${new_limit}GB${PLAIN}"
                    systemctl restart hy2-traffic-monitor.service
                else
                    echo -e "${RED}无效的输入!${PLAIN}"
                fi
                ;;
            2)
                echo -e "
当前流量:
------------------------
上传: ${GREEN}${up_gb}GB${PLAIN}
下载: ${GREEN}${down_gb}GB${PLAIN}
总计: ${GREEN}${total_gb}GB${PLAIN}
流量限制: ${YELLOW}${limit}GB${PLAIN}
------------------------"
                ;;
            3)
                if [ -f "/var/log/hysteria/traffic.log" ]; then
                    tail -n 50 /var/log/hysteria/traffic.log
                else
                    echo -e "${YELLOW}没有流量日志可用${PLAIN}"
                fi
                ;;
            4)
                systemctl restart hysteria-server.service
                systemctl restart hy2-traffic-monitor.service
                echo -e "${GREEN}流量统计重置${PLAIN}"
                ;;
            5)
                current_status=$(grep TRAFFIC_MANAGEMENT_ENABLED /etc/hysteria/traffic_config | cut -d= -f2)
                if [ "${current_status}" == "true" ]; then
                    sed -i "s/^TRAFFIC_MANAGEMENT_ENABLED=.*/TRAFFIC_MANAGEMENT_ENABLED=false/" /etc/hysteria/traffic_config
                    echo -e "${GREEN}流量管理已禁用${PLAIN}"
                    systemctl stop hy2-traffic-monitor.service
                else
                    sed -i "s/^TRAFFIC_MANAGEMENT_ENABLED=.*/TRAFFIC_MANAGEMENT_ENABLED=true/" /etc/hysteria/traffic_config
                    echo -e "${GREEN}流量管理已启用${PLAIN}"
                    systemctl start hy2-traffic-monitor.service
                fi
                ;;
            6)
                echo -e "
  ${GREEN}流量重置模式${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 每月
  ${GREEN}2.${PLAIN} 每30天
  ${GREEN}3.${PLAIN} 手动
  ${GREEN}0.${PLAIN} 返回
  ----------------------"
                read -p "输入选项 [0-3]: " reset_choice
                case "${reset_choice}" in
                    0) break ;;
                    1)
                        sed -i "s/^TRAFFIC_RESET_MODE=.*/TRAFFIC_RESET_MODE=monthly/" /etc/hysteria/traffic_config
                        echo -e "${GREEN}流量重置模式设置为每月${PLAIN}"
                        ;;
                    2)
                        sed -i "s/^TRAFFIC_RESET_MODE=.*/TRAFFIC_RESET_MODE=30days/" /etc/hysteria/traffic_config
                        echo -e "${GREEN}流量重置模式设置为每30天${PLAIN}"
                        ;;
                    3)
                        sed -i "s/^TRAFFIC_RESET_MODE=.*/TRAFFIC_RESET_MODE=manual/" /etc/hysteria/traffic_config
                        echo -e "${GREEN}流量重置模式设置为手动${PLAIN}"
                        ;;
                    *) echo -e "${RED}无效的选项 ${reset_choice}${PLAIN}" ;;
                esac
                ;;
            *) echo -e "${RED}无效的选项 ${choice}${PLAIN}" ;;
        esac
        
        echo "按回车键继续..."  # 调试信息
        read -p ""  # 读取回车键
        echo
    done
}

# 卸载 Hysteria 2
uninstall_hysteria() {
    print_info "卸载 Hysteria 2..."
    systemctl stop hysteria-server.service
    systemctl disable hysteria-server.service
    systemctl stop hy2-traffic-monitor.service
    systemctl disable hy2-traffic-monitor.service
    rm -rf /etc/hysteria
    rm -rf /root/hy2
    rm -f /usr/local/bin/catmihy2
    rm -f /usr/local/bin/hy2_traffic_monitor.sh
    rm -f /etc/systemd/system/hy2-traffic-monitor.service
    systemctl daemon-reload
    print_info "Hysteria 2 卸载成功"
}

# 更新 Hysteria 2
update_hysteria() {
    print_info "更新 Hysteria 2..."
    bash <(curl -fsSL https://get.hy2.sh/)
    if [ $? -ne 0 ]; then
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
        print_error "客户端配置文件未找到"
    fi
}

# 修改端口并同步客户端配置
modify_port() {
    read -p "输入新的端口号: " new_port
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
        print_error "无效的端口号"
        return 1
    fi
    sed -i "s/^listen: :[0-9]*$/listen: :${new_port}/" /etc/hysteria/config.yaml
    sed -i "s/^port: [0-9]*$/port: ${new_port}/" /root/hy2/config.yaml
    print_info "端口已更新为 ${new_port}"
    systemctl restart hysteria-server.service
}


# 显示菜单
show_menu() {
     clear
    echo "正在显示菜单..."
    # 获取服务状态
    hysteria_server_status=$(systemctl is-active hysteria-server.service)
    hy2_traffic_monitor_status=$(systemctl is-active hy2-traffic-monitor.service)

    if [ "${hysteria_server_status}" == "active" ]; then
        hysteria_server_status_text="${GREEN}已启用${PLAIN}"
    else
        hysteria_server_status_text="${RED}已禁用${PLAIN}"
    fi

    if [ "${hy2_traffic_monitor_status}" == "active" ]; then
        hy2_traffic_monitor_status_text="${GREEN}已启用${PLAIN}"
    else
        hy2_traffic_monitor_status_text="${RED}已禁用${PLAIN}"
    fi

    # 调用获取流量信息的函数
    get_traffic_info

    echo -e "
     echo "调试5"  # 调试信息
  ${GREEN}Hysteria 2 管理${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 安装 Hysteria 2
  ${GREEN}2.${PLAIN} 卸载 Hysteria 2
  ${GREEN}3.${PLAIN} 更新 Hysteria 2
  ${GREEN}4.${PLAIN} 重启 Hysteria 2
  ${GREEN}5.${PLAIN} 查看客户端配置
  ${GREEN}6.${PLAIN} 修改端口
  ${GREEN}7.${PLAIN} 流量管理
  ----------------------
  Hysteria 2 服务状态: ${hysteria_server_status_text}
  流量管理服务状态: ${hy2_traffic_monitor_status_text}
  流量限制: ${limit}GB
  已用流量: ${total_gb}GB
  剩余流量: ${remaining_gb}GB
  ----------------------
  ${GREEN}0.${PLAIN} 退出
  ----------------------"
    
    read -p "输入选项 [0-7]: " choice
    echo "选择的选项: ${choice}"  # 调试信息
    
    case "${choice}" in
        0) exit 0 ;;
        1) install_hysteria ;;
        2) uninstall_hysteria ;;
        3) update_hysteria ;;
        4) systemctl restart hysteria-server.service ;;
        5) view_client_config ;;
        6) modify_port ;;
        7) traffic_management ;;
        *) print_error "无效的选项 ${choice}" ;;
    esac
    
    echo "按回车键继续..."  # 调试信息
    read -p ""  # 读取回车键
    echo
     echo "菜单显示结束."  # 调试信息
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
