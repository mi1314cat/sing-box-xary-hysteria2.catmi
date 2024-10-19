#!/bin/bash

# 介绍信息
printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                   catmi-alpine-Hysteria 2 \n"
printf "       -----------------------------------------\n"
printf "Uninstalling Hysteria 2...\n"
printf "\e[0m"

# 停止 Hysteria 服务
service hysteria stop
if [ $? -ne 0 ]; then
  echo "停止 Hysteria 服务失败"
  exit 1
fi

# 移除自启动
rc-update delete hysteria
if [ $? -ne 0 ]; then
  echo "移除 Hysteria 自启动失败"
  exit 1
fi

# 删除 Hysteria 服务脚本
rm -f /etc/init.d/hysteria
if [ $? -ne 0 ]; then
  echo "删除 Hysteria 服务脚本失败"
  exit 1
fi

# 删除 Hysteria 可执行文件
rm -f /usr/local/bin/hysteria
if [ $? -ne 0 ]; then
  echo "删除 Hysteria 可执行文件失败"
  exit 1
fi

# 删除 Hysteria 配置目录和文件
rm -rf /etc/hysteria
if [ $? -ne 0 ]; then
  echo "删除 Hysteria 配置目录失败"
  exit 1
fi

# 删除客户端配置文件
rm -rf /root/hy2
if [ $? -ne 0 ]; then
  echo "删除客户端配置文件失败"
  exit 1
fi

# 删除 Hysteria 证书
rm -f /etc/hysteria/server.crt /etc/hysteria/server.key
if [ $? -ne 0 ]; then
  echo "删除 Hysteria 证书文件失败"
  exit 1
fi

echo "Hysteria 2 已成功卸载"
