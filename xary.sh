#!/bin/bash

printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                     catmi.xray \n"
printf "       -----------------------------------------\n"
printf "\e[0m"

DEFAULT_START_PORT=20000
DEFAULT_SOCKS_USERNAME="userb"
DEFAULT_SOCKS_PASSWORD="passwordb"
DEFAULT_WS_PATH="/ws$(openssl rand -hex 8)"
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

# 随机生成 WebSocket 路径
generate_random_ws_path() {
    echo "/ws$(openssl rand -hex 8)"
}

# 下载并安装最新的 Xray
install_xray() {
    echo "安装最新 Xray..."
    apt-get install unzip -y || yum install unzip -y
    LATEST_XRAY=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64.zip | cut -d '"' -f 4)
    wget $LATEST_XRAY -O Xray-linux-64.zip || { echo "下载失败！"; exit 1; }
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
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
    systemctl start xrayL.service
    echo "Xray 安装完成."
}

# 检查是否为公网IP
is_public_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^172\.1[6-9]\. ]] || [[ "$ip" =~ ^172\.2[0-9]\. ]] || [[ "$ip" =~ ^172\.3[0-1]\. ]] || [[ "$ip" =~ ^192\.168\. ]] || [[ "$ip" =~ ^127\. ]] || [[ "$ip" =~ ^169\.254\. ]]; then
        return 1  # 私有或保留IP
    fi
    return 0  # 公网IP
}

# 生成配置内容的函数
generate_config_content() {
    local config_type="$1"
    local start_port="$2"
    local socks_username="$3"
    local socks_password="$4"
    local uuid="$5"
    local ws_path="$6"
    local content=""

    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        content+="[[inbounds]]\n"
        content+="port = $((start_port + i))\n"
        content+="protocol = \"$config_type\"\n"
        content+="tag = \"tag_$((i + 1))\"\n"
        content+="[inbounds.settings]\n"
        if [ "$config_type" == "socks" ]; then
            content+="auth = \"password\"\n"
            content+="udp = true\n"
            content+="ip = \"${IP_ADDRESSES[i]}\"\n"
            content+="[[inbounds.settings.accounts]]\n"
            content+="user = \"$socks_username\"\n"
            content+="pass = \"$socks_password\"\n"
        elif [ "$config_type" == "vmess" ]; then
            content+="[[inbounds.settings.clients]]\n"
            content+="id = \"$uuid\"\n"
            content+="[inbounds.streamSettings]\n"
            content+="network = \"ws\"\n"
            content+="[inbounds.streamSettings.wsSettings]\n"
            content+="path = \"$ws_path\"\n\n"
        fi
        content+="[[outbounds]]\n"
        content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
        content+="protocol = \"freedom\"\n"
        content+="tag = \"tag_$((i + 1))\"\n\n"
        content+="[[routing.rules]]\n"
        content+="type = \"field\"\n"
        content+="inboundTag = \"tag_$((i + 1))\"\n"
        content+="outboundTag = \"tag_$((i + 1))\"\n\n\n"
    done
    echo -e "$content"
}

config_xray() {
    config_type="$1"
    mkdir -p /etc/xrayL
    if [ "$config_type" != "socks" ] && [ "$config_type" != "vmess" ]; then
        echo "类型错误！仅支持socks和vmess."
        exit 1
    fi

    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}
    if ! [[ "$START_PORT" =~ ^[0-9]+$ ]]; then
        echo "无效的端口号，必须是数字。"
        exit 1
    fi

    # 获取公网 IP 地址
    mapfile -t IP_ADDRESSES < <(ip -6 addr show | grep "inet6" | awk '{print $2}' | cut -d'/' -f1)
    PUBLIC_IP_ADDRESSES=()
    for ip in "${IP_ADDRESSES[@]}"; do
        if is_public_ip "$ip"; then
            PUBLIC_IP_ADDRESSES+=("$ip")
        fi
    done
    IP_COUNT=${#PUBLIC_IP_ADDRESSES[@]}
    
    if [ "$IP_COUNT" -eq 0 ]; then
        echo "未找到可用的公网 IPv6 地址。"
        exit 1
    fi

    if [ "$config_type" == "socks" ]; then
        read -p "SOCKS 账号 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
        SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}

        read -p "SOCKS 密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
        SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}
        config_content=$(generate_config_content "socks" "$START_PORT" "$SOCKS_USERNAME" "$SOCKS_PASSWORD" "" "")
    elif [ "$config_type" == "vmess" ]; then
        read -p "UUID (默认随机): " UUID
        UUID=${UUID:-$DEFAULT_UUID}
        read -p "WebSocket 路径 (默认 $DEFAULT_WS_PATH): " WS_PATH
        WS_PATH=${WS_PATH:-$DEFAULT_WS_PATH}
        config_content=$(generate_config_content "vmess" "$START_PORT" "" "" "$UUID" "$WS_PATH")
    fi

    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service

    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口:$START_PORT"
    echo "结束端口:$(($START_PORT + IP_COUNT - 1))"
    if [ "$config_type" == "socks" ]; then
        echo "socks账号:$SOCKS_USERNAME"
        echo "socks密码:$SOCKS_PASSWORD"
    elif [ "$config_type" == "vmess" ]; then
        echo "UUID:$UUID"
        echo "ws路径:$WS_PATH"
    fi
    echo ""
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
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
        echo "未正确选择类型，使用默认socks配置."
        config_xray "socks"
    fi
}

main "$@"
