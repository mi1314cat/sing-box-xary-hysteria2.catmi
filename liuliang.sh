#!/bin/bash

# 当前脚本文件路径
SCRIPT_URL="https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/liuliang.sh"

# 当前路径
CURRENT_DIR=$(pwd)

# 脚本文件名
SCRIPT_FILE="liuliang.sh"

# 配置文件路径
CONFIG_FILE=~/traffic_monitor.conf

# 默认阈值（GB）
DEFAULT_RX_THRESHOLD=95
DEFAULT_TX_THRESHOLD=95

# 默认流量重置日期（每月1日）
DEFAULT_CZ_DAY=1

# 默认执行指令
DEFAULT_COMMAND="shutdown -h now"

# 确保脚本文件存在并下载
if [ ! -f "$HOME/$SCRIPT_FILE" ]; then
  curl -fsSL "$SCRIPT_URL" -o "$HOME/$SCRIPT_FILE"
  echo "脚本已下载到 $HOME/$SCRIPT_FILE"
fi

# 设置脚本为可执行
chmod +x "$HOME/$SCRIPT_FILE"
# 创建快捷方式
ln -s "$HOME/$SCRIPT_FILE" "$HOME/liu"

# 读取配置文件中的阈值
read_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    echo "rx_threshold_gb=$DEFAULT_RX_THRESHOLD" > "$CONFIG_FILE"
    echo "tx_threshold_gb=$DEFAULT_TX_THRESHOLD" >> "$CONFIG_FILE"
    echo "cz_day=$DEFAULT_CZ_DAY" >> "$CONFIG_FILE"
    echo "command=\"$DEFAULT_COMMAND\"" >> "$CONFIG_FILE"
  fi
}

# 写入配置文件
write_config() {
  echo "rx_threshold_gb=$rx_threshold_gb" > "$CONFIG_FILE"
  echo "tx_threshold_gb=$tx_threshold_gb" > "$CONFIG_FILE"
  echo "cz_day=$cz_day" >> "$CONFIG_FILE"
  echo "command=\"$command\"" >> "$CONFIG_FILE"
}

# 获取当前流量
get_traffic() {
  interface=$(ls /sys/class/net | grep -v lo | head -n 1)

  if [ -z "$interface" ]; then
    echo "未找到有效的网络接口！"
    exit 1
  fi

  rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
  tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)

  echo $((rx_bytes / 1024 / 1024 / 1024)) > ~/current_rx_gb.txt
  echo $((tx_bytes / 1024 / 1024 / 1024)) > ~/current_tx_gb.txt
}

# 检查流量是否达到阈值
check_traffic() {
  current_rx_gb=$(cat ~/current_rx_gb.txt)
  current_tx_gb=$(cat ~/current_tx_gb.txt)
  if [ "$current_rx_gb" -ge "$rx_threshold_gb" ] || [ "$current_tx_gb" -ge "$tx_threshold_gb" ]; then
    echo "流量达到阈值，执行指定指令"
    execute_command
  fi
}

# 执行指定指令
execute_command() {
  echo "执行指令: $command"
  eval "$command"
}

# 主菜单
main_menu() {
  while true; do
    clear
    echo "流量监控和指令执行功能"
    echo "------------------------------------------------"
    echo "当前流量使用情况，重启服务器流量计算会清零！"
    get_traffic
    echo "当前进站流量: $(cat ~/current_rx_gb.txt) GB"
    echo "当前出站流量: $(cat ~/current_tx_gb.txt) GB"
    echo "------------------------------------------------"
    read_config
    echo "当前设置的进站限流阈值为: $rx_threshold_gb GB"
    echo "当前设置的出站限流阈值为: $tx_threshold_gb GB"
    echo "当前流量重置日期: $cz_day"
    echo "当前执行指令: $command"
    echo "------------------------------------------------"
    echo "系统每分钟会检测实际流量是否到达阈值，到达后会自动执行指定指令！"
    read -e -p "1. 设置限流阈值    2. 设置执行指令    3. 启用流量监控    4. 停用流量监控    0. 退出  : " choice

    case "$choice" in
      1)
        read -e -p "请输入进站流量阈值（单位为GB）: " rx_threshold_gb
        read -e -p "请输入出站流量阈值（单位为GB）: " tx_threshold_gb
        read -e -p "请输入流量重置日期（默认每月1日重置）: " cz_day
        cz_day=${cz_day:-1}
        write_config
        setup_cron
        echo "限流阈值已设置"
        ;;
      2)
        read -e -p "请输入要执行的指令: " command
        write_config
        echo "执行指令已设置"
        ;;
      3)
        setup_cron
        echo "已启用流量监控功能"
        ;;
      4)
        remove_cron
        echo "已关闭流量监控功能"
        ;;
      0)
        break
        ;;
      *)
        echo "无效的选择，请重新输入。"
        ;;
    esac
  done
}

# 设置定时任务
setup_cron() {
  (crontab -l ; echo "* * * * * $CURRENT_DIR/$SCRIPT_FILE check") | crontab -
  (crontab -l ; echo "0 1 $cz_day * * reboot") | crontab -
  echo "定时任务已设置"
}

# 移除定时任务
remove_cron() {
  crontab -l | grep -v "$CURRENT_DIR/$SCRIPT_FILE check" | crontab -
  crontab -l | grep -v "reboot" | crontab -
  echo "定时任务已移除"
}

# 主程序入口
main_menu
