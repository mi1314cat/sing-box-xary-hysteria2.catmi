#!/bin/bash

# 检测公网 IP
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)

echo "公网 IPv4 地址: $PUBLIC_IP_V4"
echo "公网 IPv6 地址: $PUBLIC_IP_V6"

# 选择节点类型
echo "选择生成的节点类型:"
echo "1. SOCKS"
echo "2. VMess"
echo "3. Reality"
read -p "请输入选项 (1/2/3, 默认 1): " NODE_TYPE
NODE_TYPE=${NODE_TYPE:-1}

# 输入端口
read -p "请输入端口 (默认 20000): " PORT
PORT=${PORT:-20000}

# 生成 UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# 生成公钥和短 ID
PUBLIC_KEY=$(openssl rand -hex 32)
SHORT_ID=$(openssl rand -hex 8)

# 检查 Xray 服务状态
check_xray_status() {
    echo "Xray 运行状况："
    systemctl status xrayL.service
}

# 创建配置文件
CONFIG_FILE="/etc/xrayL/config.toml"

case $NODE_TYPE in
    1)
        PROTOCOL="socks"
        echo "选择的节点类型: SOCKS"
        ;;
    2)
        PROTOCOL="vmess"
        echo "选择的节点类型: VMess"
        ;;
    3)
        PROTOCOL="vless"
        echo "选择的节点类型: Reality"
        ;;
    *)
        echo "未正确选择类型，使用默认 SOCKS 配置."
        PROTOCOL="socks"
        ;;
esac

# 生成 Reality 配置
if [ "$PROTOCOL" == "vless" ]; then
    cat <<EOF > $CONFIG_FILE
{
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": $PORT, 
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "rejectUnknownSni": true,
                    "minVersion": "1.2",
                    "certificates": [ 
                        {
                            "ocspStapling": 3600,
                            "certificateFile": "/root/cert/cert.crt",
                            "keyFile": "/root/cert/private.key"
                        }
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
fi

# 输出 Xray 运行状况
check_xray_status

# 输出节点信息
echo "生成的 Reality 配置:"
echo "- name: Reality-Vision"
echo "  type: vless"
echo "  server: $PUBLIC_IP_V4"
echo "  port: $PORT"
echo "  uuid: $UUID"
echo "  network: tcp"
echo "  udp: true"
echo "  tls: true"
echo "  flow: xtls-rprx-vision"
echo "  servername: itunes.apple.com"
echo "  client-fingerprint: chrome"
echo "  reality-opts:"
echo "    public-key: $PUBLIC_KEY"
echo "    short-id: $SHORT_ID"

# 设置 Xray 自启
systemctl enable xrayL.service
echo "Xray 服务已设置为开机自启."

# 提示用户重启服务
echo "请重启 Xray 服务以应用配置:"
echo "sudo systemctl restart xrayL.service"
