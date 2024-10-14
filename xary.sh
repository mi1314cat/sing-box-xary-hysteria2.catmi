#!/bin/bash

DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_SOCKS_USERNAME="userb"                   # 默认 SOCKS 账号
DEFAULT_SOCKS_PASSWORD="passwordb"               # 默认 SOCKS 密码
DEFAULT_WS_PATH=$(cat /proc/sys/kernel/random/uuid)  # 默认随机 UUID
DEFAULT_PUBLIC_KEY=$(openssl rand -hex 32)      # 生成默认公钥
DEFAULT_SHORT_ID=$(openssl rand -hex 16)        # 生成默认短 ID

# 获取公网 IP 地址
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)
echo "公网 IPv4 地址: $PUBLIC_IP_V4"
echo "公网 IPv6 地址: $PUBLIC_IP_V6"

# 定义安装 Xray 的函数
install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    LATEST_XRAY=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64.zip | cut -d '"' -f 4)
    wget $LATEST_XRAY -O Xray-linux-64.zip
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

# 定义配置 Xray 的函数
config_xray() {
    config_type=$1
    mkdir -p /etc/xrayL
    if [ "$config_type" != "socks" ] && [ "$config_type" != "vmess" ] && [ "$config_type" != "reality" ]; then
        echo "类型错误！仅支持 socks、vmess 和 reality."
        exit 1
    fi

    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}

    if [ "$config_type" == "socks" ]; then
        read -p "SOCKS 账号 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
        SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}

        read -p "SOCKS 密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
        SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}

        config_content+="[[inbounds]]\n"
        config_content+="port = $START_PORT\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"socks\"\n"
        config_content+="[inbounds.settings]\n"
        config_content+="auth = \"password\"\n"
        config_content+="udp = true\n"
        config_content+="[[inbounds.settings.accounts]]\n"
        config_content+="user = \"$SOCKS_USERNAME\"\n"
        config_content+="pass = \"$SOCKS_PASSWORD\"\n"

    elif [ "$config_type" == "vmess" ]; then
        read -p "UUID (默认随机): " UUID
        UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}
        read -p "WebSocket 路径 (默认随机): " WS_PATH
        WS_PATH=${WS_PATH:-/$(cat /proc/sys/kernel/random/uuid)}

        config_content+="[[inbounds]]\n"
        config_content+="port = $START_PORT\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"vmess\"\n"
        config_content+="[inbounds.settings]\n"
        config_content+="[[inbounds.settings.clients]]\n"
        config_content+="id = \"$UUID\"\n"
        config_content+="[inbounds.streamSettings]\n"
        config_content+="network = \"ws\"\n"
        config_content+="[inbounds.streamSettings.wsSettings]\n"
        config_content+="path = \"$WS_PATH\"\n"

    elif [ "$config_type" == "reality" ]; then
        read -p "输入端口: " REALITY_PORT
        REALITY_PORT=${REALITY_PORT:-52110}
        UUID=$(cat /proc/sys/kernel/random/uuid)

        config_content+="[[inbounds]]\n"
        config_content+="port = $REALITY_PORT\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"reality\"\n"
        config_content+="[inbounds.settings]\n"
        config_content+="[[inbounds.settings.clients]]\n"
        config_content+="id = \"$UUID\"\n"
        config_content+="[inbounds.streamSettings]\n"
        config_content+="network = \"tcp\"\n"
        config_content+="udp = true\n"
        config_content+="tls = true\n"
        config_content+="flow = \"xtls-rprx-vision\"\n"
        config_content+="[inbounds.streamSettings.realityOpts]\n"
        config_content+="public-key = \"$DEFAULT_PUBLIC_KEY\"\n"
        config_content+="short-id = \"$DEFAULT_SHORT_ID\"\n"

    fi

    config_content+="[[outbounds]]\n"
    config_content+="sendThrough = \"$PUBLIC_IP_V4\"\n"
    config_content+="protocol = \"freedom\"\n"
    config_content+="tag = \"outbound\"\n\n"

    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service

    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口: $START_PORT"
    echo "结束端口: $((START_PORT + 1))"
    if [ "$config_type" == "socks" ]; then
        echo "SOCKS 账号: $SOCKS_USERNAME"
        echo "SOCKS 密码: $SOCKS_PASSWORD"
    elif [ "$config_type" == "vmess" ]; then
        echo "UUID: $UUID"
        echo "WebSocket 路径: $WS_PATH"
    elif [ "$config_type" == "reality" ]; then
        echo "UUID: $UUID"
        echo "公钥: $DEFAULT_PUBLIC_KEY"
        echo "短 ID: $DEFAULT_SHORT_ID"
    fi

    echo ""
}

main() {
    if [ ! -x "/usr/local/bin/xrayL" ]; then
        install_xray
    fi

    if [ $# -eq 1 ]; then
        config_type="$1"
    else
        read -p "选择生成的节点类型 (socks/vmess/reality): " config_type
    fi

    if [ "$config_type" == "vmess" ]; then
        config_xray "vmess"
    elif [ "$config_type" == "socks" ]; then
        config_xray "socks"
    elif [ "$config_type" == "reality" ]; then
        config_xray "reality"
    else
        echo "未正确选择类型，使用默认 socks 配置."
        config_xray "socks"
    fi
}

main "$@"
