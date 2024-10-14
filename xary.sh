#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 身份运行此脚本"
  exit 1
fi

# 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    ARCH_TYPE="linux_amd64"
    ;;
  aarch64)
    ARCH_TYPE="linux_arm64"
    ;;
  armv7l)
    ARCH_TYPE="linux_arm32"
    ;;
  *)
    echo "不支持的架构: $ARCH"
    exit 1
    ;;
esac

# 获取最新版本的下载链接
latest_release=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest)
download_url=$(echo "$latest_release" | grep "browser_download_url" | grep "$ARCH_TYPE" | cut -d '"' -f 4)

if [ -z "$download_url" ]; then
  echo "未找到适合该架构的 Xray 版本。"
  exit 1
fi

# 下载最新版本
echo "正在下载适合 $ARCH_TYPE 的最新 Xray 版本..."
curl -L -o xray.zip "$download_url"

# 解压缩下载的文件
echo "正在解压缩..."
unzip xray.zip
chmod +x xray

# 移动到 /usr/local/bin 目录
mv xray /usr/local/bin/

# 清理
rm xray.zip

# 创建配置文件目录
mkdir -p /etc/xray/

# 自动生成 UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# 创建默认配置文件
cat << EOF > /etc/xray/config.json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "your.server.ip",
        "port": 443,
        "users": [{
          "id": "$uuid",
          "flow": "xtls-rprx-vision",
          "email": "user@example.com"
        }]
      }]
    }
  }],
  "inbounds": [{
    "port": 443,
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
        "publicKey": "your-public-key",
        "shortId": "your-short-id"
      }
    }
  }]
}
EOF

# 设置 Xray 自启（如果需要）
echo "设置 Xray 为开机自启..."
systemctl enable xray
systemctl start xray

# 显示 Xray 运行状态
echo "Xray 运行状态:"
systemctl status xray

# 输出格式化的节点配置
echo "格式化的节点配置:"
cat << EOF
name: Reality-Vision
type: vless
server: your.server.ip
port: 443
uuid: $uuid
network: tcp
udp: true
tls: true
flow: xtls-rprx-vision
servername: itunes.apple.com
client-fingerprint: chrome
reality-opts:
  public-key: your-public-key
  short-id: your-short-id
EOF

# 生成并输出 VLESS 链接
vless_link="vless://$uuid@your.server.ip:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=itunes.apple.com&fp=chrome&pbk=your-public-key&sid=your-short-id&type=tcp&headerType=none"
echo "VLESS 链接:"
echo "$vless_link"

echo "Xray 安装及配置完成!"
