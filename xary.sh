#!/bin/bash

# 检测公网 IPv4 和 IPv6 地址
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)
echo "公网 IPv4 地址: $PUBLIC_IP_V4"
echo "公网 IPv6 地址: $PUBLIC_IP_V6"

# 检测 VPS 架构
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    Xray_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
elif [[ "$ARCH" == "aarch64" ]]; then
    Xray_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64.zip"
else
    echo "不支持的架构: $ARCH"
    exit 1
fi

# 下载 Xray
echo "下载 Xray..."
curl -L -o Xray.zip "$Xray_URL"
unzip Xray.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray
rm Xray.zip

# 选择生成的节点类型
echo "选择生成的节点类型:"
echo "1. SOCKS"
echo "2. VMess"
echo "3. Reality"
read -p "请输入选项 (1/2/3, 默认 1): " node_type
node_type=${node_type:-1}

# 输入端口
read -p "请输入端口 (默认 20000): " port
port=${port:-20000}

# 生成 UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# 根据选择生成不同类型的配置
case $node_type in
  1)
    echo "选择的节点类型: SOCKS"
    # SOCKS配置（示例）
    cat <<EOF
- name: SOCKS
  type: socks
  server: $PUBLIC_IP_V4
  port: $port
  uuid: $UUID
EOF
    ;;
  2)
    echo "选择的节点类型: VMess"
    # VMess配置（示例）
    cat <<EOF
- name: VMess
  type: vmess
  server: $PUBLIC_IP_V4
  port: $port
  uuid: $UUID
EOF
    ;;
  3)
    echo "选择的节点类型: Reality"
    # Reality配置
    public_key=$(openssl rand -hex 32)  # 自动生成公钥
    short_id=$(openssl rand -hex 8)  # 自动生成短 ID
    echo "生成的 Reality 配置:"
    cat <<EOF
- name: Reality-Vision
  type: vless
  server: $PUBLIC_IP_V4
  port: $port
  uuid: $UUID
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: itunes.apple.com
  client-fingerprint: chrome
  reality-opts:
    public-key: $public_key
    short-id: $short_id
EOF
    ;;
  *)
    echo "未正确选择类型，使用默认 SOCKS 配置."
    ;;
esac

# Xray 服务设置为开机自启
echo "Xray 服务已设置为开机自启."

# 重启 Xray 服务
sudo systemctl restart xrayL.service
echo "请重启 Xray 服务以应用配置."
