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
    local protocol="$1"
    while :; do
        port=$((RANDOM % 10001 + 10000))
        read -p "请为 ${protocol} 输入监听端口(默认为随机生成): " user_input
        port=${user_input:-$port}
        ss -tuln | grep -q ":$port\b" || { echo "$port"; return $port; }
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
    # 获取当前的端口和密码
    current_port=$(grep -oP '(?<=listen: ")[0-9]+' /etc/hysteria/config.yaml)
    current_password=$(grep -oP '(?<=password: ).*' /etc/hysteria/config.yaml)

    read -p "请输入新的端口号 (当前: ${current_port}, 默认随机生成): " new_port
    new_port=${new_port:-$(generate_port "Hysteria")}

    read -p "请输入新的密码 (当前: ${current_password}, 默认随机生成): " new_password
    new_password=${new_password:-$(openssl rand -base64 16)}

    # 输出修改前的配置
    echo "修改前服务端配置内容:"
    cat /etc/hysteria/config.yaml

    # 修改服务端配置
    if sed -i "s|^listen: \".*\"|listen: \"${new_port}\"|" /etc/hysteria/config.yaml; then
        echo "成功修改服务端的端口号"
    else
        echo "修改服务端的端口号失败"
        return 1
    fi

    # 修改服务端密码
    if sed -i "s|^ *password: .*|  password: ${new_password}|" /etc/hysteria/config.yaml; then
        echo "成功修改服务端的密码"
    else
        echo "修改服务端的密码失败"
        return 1
    fi

    # 修改客户端配置
    if sed -i "s/^port: 7890$/port: 7890/" /root/hy2/config.yaml; then
        echo "客户端端口未修改，保持为 7890"
    fi

    # 修改客户端中的代理端口和密码
    if sed -i "s/^\s*port: [0-9]*$/port: ${new_port}/" /root/hy2/config.yaml; then
        echo "成功修改客户端的代理端口号"
    else
        echo "修改客户端的代理端口号失败"
        return 1
    fi

    if sed -i "s|^\s*password: .*|password: ${new_password}|" /root/hy2/config.yaml; then
        echo "成功修改客户端的密码"
    else
        echo "修改客户端的密码失败"
        return 1
    fi

    # 输出修改后的配置
    echo "修改后服务端配置内容:"
    cat /etc/hysteria/config.yaml
    echo "修改后客户端配置内容:"
    cat /root/hy2/config.yaml

    echo "配置已修改为："
    echo "端口：${new_port}"
    echo "密码：${new_password}"

    # 重启服务
    if systemctl restart hysteria-server.service; then
        echo "服务已重启"
    else
        echo "重启服务失败"
    fi
}

# 主菜单
show_menu() {
    # 获取服务状态
    hysteria_server_status=$(systemctl is-active hysteria-server.service)
    hysteria_server_status_text=$(if [[ "$hysteria_server_status" == "active" ]]; then echo -e "${GREEN}启动${PLAIN}"; else echo -e "${RED}未启动${PLAIN}"; fi)
    
    # 显示菜单
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
        1) bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/H3hy2.sh) ;;
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
