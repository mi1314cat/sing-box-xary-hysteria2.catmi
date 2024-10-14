#!/bin/bash

printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                       catmi \n"
printf "       -----------------------------------------\n"
printf "\e[0m"
DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_SOCKS_USERNAME="userb"                   # 默认socks账号
DEFAULT_SOCKS_PASSWORD="passwordb"               # 默认socks密码
DEFAULT_WS_PATH="/ws"                            # 默认ws路径
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid) # 默认随机UUID

# 自动检测公网 IPv4 和 IPv6 地址
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)

if [[ -z "$PUBLIC_IP_V4" && -z "$PUBLIC_IP_V6" ]]; then
    echo "没有检测到公网 IP，手动输入 IP 地址:"
    read -p "请输入 IP 地址: " MANUAL_IP
    PUBLIC_IPS=($MANUAL_IP)
else
    echo "公网 IPv4 地址: $PUBLIC_IP_V4"
    echo "公网 IPv6 地址: $PUBLIC_IP_V6"
    PUBLIC_IPS=($PUBLIC_IP_V4 $PUBLIC_IP_V6)
fi

# 随机生成 WebSocket 路径
generate_random_ws_path() {
    echo "/ws$(openssl rand -hex 8)"
}

# 下载并安装最新的 Xray
install_xray() {
    echo "安装最新 Xray..."
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
    echo "起始端口: $START_PORT"
    echo "结束端口: $(($START_PORT + ${#PUBLIC_IPS[@]} - 1))"

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
