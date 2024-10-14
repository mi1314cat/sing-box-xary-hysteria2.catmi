#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 身份运行此脚本"
  exit 1
fi

# 下载并安装 Xray
echo "正在下载并安装 Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 检测服务器 IP
server_ip=$(curl -s http://ipinfo.io/ip)

# 用户输入端口
read -p "请输入您希望使用的端口: " port

# 自动生成 UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# 生成节点配置文件
cat << EOF > /etc/xray/config.json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "$server_ip",
        "port": $port,
        "users": [{
          "id": "$uuid",
          "flow": "xtls-rprx-vision",
          "email": "user@example.com"
        }]
      }]
    }
  }],
  "inbounds": [{
    "port": $port,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "alterId": 0
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "serverName": "itunes.apple.com",
        "allowInsecure": false
      },
      "realitySettings": {
        "publicKey": "\$public_key",
        "shortId": "\$short_id"
      }
    }
  }]
}
EOF

# 设置 Xray 自启
echo "设置 Xray 为开机自启..."
systemctl enable xray
systemctl start xray

# 输出节点信息
echo "节点信息如下:"
echo "节点名称: Reality-Vision"
echo "类型: vless"
echo "服务器: $server_ip"
echo "端口: $port"
echo "UUID: $uuid"
echo "网络: tcp"
echo "UDP: true"
echo "TLS: true"
echo "流: xtls-rprx-vision"
echo "服务器名称: itunes.apple.com"
echo "客户端指纹: chrome"
echo "公钥: \$public_key"
echo "短 ID: \$short_id"

echo "Xray 安装及配置完成!"
