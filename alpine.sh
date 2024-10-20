#!/bin/bash
# 介绍信息
printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                    alpine-catmi \n"
printf "       -----------------------------------------\n"
printf "\e[0m"
apk add update
apk add wget bash curl sudo
read -p "按回车继续执行第一个脚本..."
clear

bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/alpine-hysteria2.sh)
# 添加回车等待
read -p "按回车继续执行第二个脚本..."

curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
