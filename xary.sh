#!/bin/bash

# 检测公网 IPv4 和 IPv6 地址
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)
echo "公网 IPv4 地址: $PUBLIC_IP_V4"
echo "公网 IPv6 地址: $PUBLIC_IP_V6"

# 下载并安装最新版本的 Xray-core
echo "正在下载最新版本的 Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 配置 Xray-core 使用 User=nobody
Xray_SERVICE_FILE="/etc/systemd/system/xrayL.service"
if [ -f "$Xray_SERVICE_FILE" ]; then
    echo "正在配置 Xray 服务..."
    sudo sed -i 's/^User=.*$/User=nobody/' "$Xray_SERVICE_FILE"
else
    echo "找不到 Xray 服务文件，无法设置 User=nobody."
fi

# 确保不覆盖现有服务文件
echo "确保不覆盖现有服务文件..."

# 输入节点类型
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

# 创建配置文件
CONFIG_FILE="/etc/xrayL/config.toml"

case $NODE_TYPE in
    1)
        PROTOCOL="socks"
        echo "选择的节点类型: SOCKS"
        # SOCKS配置
        cat <<EOF > $CONFIG_FILE
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $PORT,
            "listen": "0.0.0.0",
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
        ;;
    2)
        PROTOCOL="vmess"
        echo "选择的节点类型: VMess"
        # VMess配置
        cat <<EOF > $CONFIG_FILE
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $PORT,
            "listen": "0.0.0.0",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "alterId": 64
                    }
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
        ;;
    3)
        PROTOCOL="vless"
        echo "选择的节点类型: Reality"
        # Reality配置
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
        ;;
    *)
        echo "未正确选择类型，使用默认 SOCKS 配置."
        # 默认 SOCKS配置
        cat <<EOF > $CONFIG_FILE
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $PORT,
            "listen": "0.0.0.0",
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
        ;;
esac

# 设置 Xray 自启
echo "设置 Xray 服务为开机自启..."
sudo systemctl enable xrayL.service

# 输出 Xray 运行状况
echo "Xray 运行状况："
sudo systemctl status xrayL.service

# 输出节点信息
echo "生成的节点配置:"
echo "- name: Reality-Vision"
echo "  type: $PROTOCOL"
echo "  server: $PUBLIC_IP_V4"
echo "  port: $PORT"
echo "  uuid: $UUID"
if [ "$PROTOCOL" == "vless" ]; then
    echo "  flow: xtls-rprx-vision"
    echo "  reality-opts:"
    echo "    public-key: $PUBLIC_KEY"
    echo "    short-id: $SHORT_ID"
fi

# 提示用户重启服务
echo "请重启 Xray 服务以应用配置:"
echo "sudo systemctl restart xrayL.service"
