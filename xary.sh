#!/bin/bash

# 默认设置
DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_SOCKS_USERNAME="userb"                   # 默认 SOCKS 账号
DEFAULT_SOCKS_PASSWORD="passwordb"               # 默认 SOCKS 密码
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid) # 默认随机 UUID

# 获取 IP 地址
IP_ADDRESSES=($(hostname -I))

# 检测公网 IPv4 和 IPv6
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)
echo "公网 IPv4 地址: $PUBLIC_IP_V4"
echo "公网 IPv6 地址: $PUBLIC_IP_V6"

# 安装 Xray
install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    wget https://github.com/XTLS/Xray-core/releases/download/$LATEST_VERSION/Xray-linux-64.zip
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

# 配置 Xray
config_xray() {
    config_type=$1
    mkdir -p /etc/xrayL
    if [ "$config_type" != "socks" ] && [ "$config_type" != "vmess" ] && [ "$config_type" != "reality" ]; then
        echo "类型错误！仅支持 SOCKS、VMess 和 Reality."
        exit 1
    fi

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
        WS_PATH=$(cat /proc/sys/kernel/random/uuid) # 随机生成 WebSocket 路径
        echo "WebSocket 路径 (随机生成): $WS_PATH"
    elif [ "$config_type" == "reality" ]; then
        read -p "输入端口: " INPUT_PORT
        PORT=${INPUT_PORT:-$START_PORT}
        UUID=$(cat /proc/sys/kernel/random/uuid) # 随机生成 UUID
        PUBLIC_KEY=$(openssl rand -hex 32) # 生成公钥
        SHORT_ID=$(openssl rand -hex 8) # 生成短 ID
    fi

    config_content=""
    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        config_content+="[[inbounds]]\n"
        config_content+="port = $((START_PORT + i))\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n"
        config_content+="[inbounds.settings]\n"

        if [ "$config_type" == "socks" ]; then
            config_content+="auth = \"password\"\n"
            config_content+="udp = true\n"
            config_content+="ip = \"${IP_ADDRESSES[i]}\"\n"
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
        elif [ "$config_type" == "reality" ]; then
            config_content+="[[inbounds.settings.clients]]\n"
            config_content+="id = \"$UUID\"\n"
            config_content+="[inbounds.streamSettings]\n"
            config_content+="network = \"tcp\"\n"
            config_content+="udp = true\n"
            config_content+="tls = true\n"
            config_content+="flow = \"xtls-rprx-vision\"\n"
            config_content+="[inbounds.reality]\n"
            config_content+="public-key = \"$PUBLIC_KEY\"\n"
            config_content+="short-id = \"$SHORT_ID\"\n"
        fi

        config_content+="[[outbounds]]\n"
        config_content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="protocol = \"freedom\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n\n"
        config_content+="[[routing.rules]]\n"
        config_content+="type = \"field\"\n"
        config_content+="inboundTag = \"tag_$((i + 1))\"\n"
        config_content+="outboundTag = \"tag_$((i + 1))\"\n\n\n"
    done
    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service
    echo "Xray 运行状况："
    systemctl --no-pager status xrayL.service

    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口: $START_PORT"
    if [ "$config_type" == "reality" ]; then
        echo "输入端口: $PORT"
    fi
    echo "结束端口: $(($START_PORT + i - 1))"
    if [ "$config_type" == "socks" ]; then
        echo "SOCKS 账号: $SOCKS_USERNAME"
        echo "SOCKS 密码: $SOCKS_PASSWORD"
    elif [ "$config_type" == "vmess" ]; then
        echo "UUID: $UUID"
        echo "WebSocket 路径: $WS_PATH"
    elif [ "$config_type" == "reality" ]; then
        echo "UUID: $UUID"
        echo "公钥: $PUBLIC_KEY"
        echo "短 ID: $SHORT_ID"
    fi
    echo ""
}

# 主程序
main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    echo "选择生成的节点类型:"
    echo "1) SOCKS"
    echo "2) VMess"
    echo "3) Reality"
    read -p "输入选项 (1/2/3): " option
    case $option in
        1) config_xray "socks" ;;
        2) config_xray "vmess" ;;
        3) config_xray "reality" ;;
        *) echo "未正确选择类型，使用默认 SOCKS 配置." && config_xray "socks" ;;
    esac
}

main "$@"
