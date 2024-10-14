#!/bin/bash

DEFAULT_START_PORT=20000                         # 默认起始端口
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

# 生成公钥和私钥对用于 Reality
generate_reality_keys() {
    # 使用 Xray 生成 Reality 密钥对
    keys=$(xray x25519)
    if [[ $? -ne 0 ]]; then
        echo "生成 Reality 密钥对失败，请检查 Xray 是否正确安装并配置。"
        exit 1
    fi
    private_key=$(echo "$keys" | grep "Private key" | cut -d ' ' -f3)
    public_key=$(echo "$keys" | grep "Public key" | cut -d ' ' -f3)
    
    # 检查是否成功提取公钥和私钥
    if [[ -z "$public_key" || -z "$private_key" ]]; then
        echo "未能成功生成公钥和私钥。"
        exit 1
    fi

    echo "私钥: $private_key"
    echo "公钥: $public_key"
}

# 生成短 ID
generate_short_id() {
    echo "$(openssl rand -hex 8)"
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

# 配置 Reality 协议
config_reality() {
    mkdir -p /etc/xrayL

    read -p "请输入端口 (默认 $DEFAULT_START_PORT): " PORT
    PORT=${PORT:-$DEFAULT_START_PORT}
    UUID=${DEFAULT_UUID}

    # 生成公钥和短 ID
    generate_reality_keys
    short_id=$(generate_short_id)

    # 构建 Reality 配置
    config_content="[[inbounds]]\n"
    config_content+="port = $PORT\n"
    config_content+="protocol = \"vless\"\n"
    config_content+="tag = \"reality\"\n"
    config_content+="[inbounds.settings]\n"
    config_content+="clients = [{id = \"$UUID\"}]\n"
    config_content+="decryption = \"none\"\n"
    config_content+="[inbounds.streamSettings]\n"
    config_content+="network = \"tcp\"\n"
    config_content+="security = \"reality\"\n"
    config_content+="[inbounds.streamSettings.realitySettings]\n"
    config_content+="publicKey = \"$public_key\"\n"  # 使用生成的公钥
    config_content+="shortIds = [\"$short_id\"]\n\n"  # 使用生成的短 ID

    config_content+="[[outbounds]]\n"
    config_content+="protocol = \"freedom\"\n"
    config_content+="sendThrough = \"${PUBLIC_IP_V4}\"\n"
    config_content+="tag = \"reality_outbound\"\n"

    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service

    # 显示 Xray 服务的运行状况
    echo "Xray 运行状况："
    systemctl --no-pager status xrayL.service

    echo ""
    echo "Reality 配置生成完成"
    echo "端口: $PORT"
    echo "UUID: $UUID"
    echo "公钥: $public_key"
    echo "短 ID: $short_id"
    echo "配置文件位于: /etc/xrayL/config.toml"
    
    # 输出 Reality-Vision 配置
    echo -e "\n生成的 Reality-Vision 配置:"
    echo "- name: Reality-Vision"
    echo "  type: vless"
    echo "  server: ${PUBLIC_IP_V4:-$MANUAL_IP}"  # 使用自动识别的公网 IP 或手动输入的 IP
    echo "  port: $PORT"
    echo "  uuid: $UUID"
    echo "  network: tcp"
    echo "  udp: true"
    echo "  tls: true"
    echo "  flow: xtls-rprx-vision"
    echo "  servername: itunes.apple.com"
    echo "  client-fingerprint: chrome"
    echo "  reality-opts:"
    echo "    public-key: $public_key"  # 使用生成的公钥
    echo "    short-id: $short_id"      # 使用生成的短 ID
    echo ""
}

# 主函数
main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_reality
}

main "$@"
