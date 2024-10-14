#!/bin/bash

# 默认参数设置
DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_SOCKS_USERNAME="userb"                   # 默认 SOCKS 账号
DEFAULT_SOCKS_PASSWORD="passwordb"               # 默认 SOCKS 密码
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid) # 随机生成 UUID
DEFAULT_WS_PATH="/ws"                            # 默认 WebSocket 路径，若不指定则随机生成

# 获取服务器公网 IP 地址，如果没有公网 IP，则提示用户输入
get_public_ip() {
    IP_ADDRESSES=($(hostname -I))
    PUBLIC_IPS=()

    for ip in "${IP_ADDRESSES[@]}"; do
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ ! "$ip" =~ ^(10\.|172\.16|192\.168) ]]; then
            PUBLIC_IPS+=("$ip")
        fi
    done

    if [ ${#PUBLIC_IPS[@]} -eq 0 ]; then
        read -p "没有检测到公网 IP，手动输入 IP 地址: " MANUAL_IP
        PUBLIC_IPS+=("$MANUAL_IP")
    fi
}

# 自动下载最新 Xray 版本
install_xray() {
    echo "安装 Xray..."
    
    if ! command -v xrayL &> /dev/null; then
        apt-get install -y unzip wget || yum install -y unzip wget

        # 获取最新的 Xray 版本号
        latest_version=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        echo "正在下载 Xray 版本: $latest_version"
        
        # 下载并安装最新版本
        wget https://github.com/XTLS/Xray-core/releases/download/$latest_version/Xray-linux-64.zip
        unzip Xray-linux-64.zip
        mv xray /usr/local/bin/xrayL
        chmod +x /usr/local/bin/xrayL
        rm -f Xray-linux-64.zip

        # 创建 Xray systemd 服务
        cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable xrayL.service
        echo "Xray 安装完成并设置为开机自启."
    else
        echo "Xray 已经安装."
    fi
}

# 随机生成 WebSocket 路径
generate_random_ws_path() {
    WS_PATH=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
    echo "/$WS_PATH"
}

# 配置 Xray
config_xray() {
    config_type=$1
    mkdir -p /etc/xrayL

    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}

    if [ "$config_type" == "socks" ]; then
        read -p "SOCKS 账号 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
        SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}

        read -p "SOCKS 密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
        SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}
    elif [ "$config_type" == "vmess" ]; then
        read -p "UUID (默认随机): " UUID
        UUID=${UUID:-$DEFAULT_UUID}

        read -p "WebSocket 路径 (默认随机): " WS_PATH
        WS_PATH=${WS_PATH:-$(generate_random_ws_path)}
    fi

    config_content=""

    for ((i = 0; i < ${#PUBLIC_IPS[@]}; i++)); do
        config_content+="[[inbounds]]\n"
        config_content+="port = $((START_PORT + i))\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n"
        config_content+="[inbounds.settings]\n"
        if [ "$config_type" == "socks" ]; then
            config_content+="auth = \"password\"\n"
            config_content+="udp = true\n"
            config_content+="ip = \"${PUBLIC_IPS[i]}\"\n"
            config_content+="[[inbounds.settings.accounts]]\n"
            config_content+="user = \"$SOCKS_USERNAME\"\n"
            config_content+="pass = \"$SOCKS_PASSWORD\"\n"
        elif [ "$config_type" == "vmess" ]; then
            config_content+="[[inbounds.settings.clients]]\n"
            config_content+="id = \"$UUID\"\n"
            config_content+="[inbounds.streamSettings]\n"
            config_content+="network = \"ws\"\n"
            config_content+="[inbounds.streamSettings.wsSettings]\n"
            config_content+="path = \"$WS_PATH\"\n\n"
        fi

        config_content+="[[outbounds]]\n"
        config_content+="sendThrough = \"${PUBLIC_IPS[i]}\"\n"  # 指定出口 IP
        config_content+="protocol = \"freedom\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n\n"
    done

    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service

    # 显示 Xray 服务的运行状况
    echo "Xray 运行状况："
    systemctl --no-pager status xrayL.service

    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口:$START_PORT"
    echo "结束端口:$(($START_PORT + ${#PUBLIC_IPS[@]} - 1))"
    
    # 输出配置信息
    if [ "$config_type" == "socks" ]; then
        echo "socks账号: $SOCKS_USERNAME"
        echo "socks密码: $SOCKS_PASSWORD"
    elif [ "$config_type" == "vmess" ]; then
        echo "UUID: $UUID"
        echo "WebSocket路径: $WS_PATH"
    fi
    echo "配置文件位于: /etc/xrayL/config.toml"
    echo ""
}


# 主函数
main() {
    get_public_ip
    install_xray

    if [ $# -eq 1 ]; then
        config_type="$1"
    else
        read -p "选择生成的节点类型 (socks/vmess): " config_type
    fi

    if [ "$config_type" == "vmess" ]; then
        config_xray "vmess"
    elif [ "$config_type" == "socks" ]; then
        config_xray "socks"
    else
        echo "未正确选择类型，使用默认 SOCKS 配置."
        config_xray "socks"
    fi
}

main "$@"
