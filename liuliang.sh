#!/bin/bash

# Define constants
SCRIPT_URL="https://github.com/mi1314cat/sary-hysteria2.catmi/raw/refs/heads/main/liuliang.sh"
CONFIG_FILE=~/traffic_monitor.conf
DEFAULT_RX_THRESHOLD=95
DEFAULT_TX_THRESHOLD=95
DEFAULT_CZ_DAY=1
DEFAULT_COMMAND="reboot"

# Check if script file exists, download it if it doesn't
if [! -f "$HOME/liuliang.sh" ]; then
  curl -fsSL "$SCRIPT_URL" -o "$HOME/liuliang.sh" || {
    echo "Failed to download script file"
    exit 1
  }
fi

# Make script file executable
chmod +x "$HOME/liuliang.sh" || {
  echo "Failed to make script file executable"
  exit 1
}

# Create symbolic link to script file
ln -s "$HOME/liuliang.sh" "$HOME/liu" || {
  echo "Failed to create symbolic link"
  exit 1
}

# Read config file
read_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    echo "rx_threshold_gb=$DEFAULT_RX_THRESHOLD" > "$CONFIG_FILE"
    echo "tx_threshold_gb=$DEFAULT_TX_THRESHOLD" >> "$CONFIG_FILE"
    echo "cz_day=$DEFAULT_CZ_DAY" >> "$CONFIG_FILE"
    echo "command=\"$DEFAULT_COMMAND\"" >> "$CONFIG_FILE"
    source "$CONFIG_FILE"
  fi
}

# Write config file
write_config() {
  echo "rx_threshold_gb=$rx_threshold_gb" > "$CONFIG_FILE"
  echo "tx_threshold_gb=$tx_threshold_gb" >> "$CONFIG_FILE"
  echo "cz_day=$cz_day" >> "$CONFIG_FILE"
  echo "command=\"$command\"" >> "$CONFIG_FILE"
}

# Get traffic statistics
get_traffic() {
  interface=$(ls /sys/class/net | grep -v lo | head -n 1)
  if [ -z "$interface" ]; then
    echo "Failed to get network interface"
    exit 1
  fi

  rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
  tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")

  echo "$((rx_bytes / 1024 / 1024 / 1024))" > ~/current_rx_gb.txt
  echo "$((tx_bytes / 1024 / 1024 / 1024))" > ~/current_tx_gb.txt
}

# Output traffic statistics
output_status() {
  output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
    NR > 2 { rx_total += $2; tx_total += $10 }
    END {
      rx_units = "Bytes";
      tx_units = "Bytes";
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

      if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
      if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
      if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

      printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
    }' /proc/net/dev)
  echo "$output"
}

# Check traffic
check_traffic() {
  current_rx_gb=$(cat ~/current_rx_gb.txt)
  current_tx_gb=$(cat ~/current_tx_gb.txt)
  if [ "$current_rx_gb" -ge "$rx_threshold_gb" ] || [ "$current_tx_gb" -ge "$tx_threshold_gb" ]; then
    echo "Traffic exceeded threshold, executing command"
    execute_command
  fi
}

# Execute command
execute_command() {
  "$command"
}

# Main menu
main_menu() {
  while true; do
    clear
    echo "流量监控和指令执行功能"
    echo "------------------------------------------------"
    echo "当前流量使用情况，重启服务器流量计算会清零！"
    get_traffic
    output_status
    echo "当前进站流量: $(cat ~/current_rx_gb.txt) GB"
    echo "当前出站流量: $(cat ~/current_tx_gb.txt) GB"
    echo "------------------------------------------------"
    read_config
    echo "当前设置的进站限流阈值为: $rx_threshold_gb GB"
    echo "当前设置的出站限流阈值为: $tx_threshold_gb GB"
    echo "当前流量重置日期: $cz_day"
    echo "当前执行指令: $command"
    echo "------------------------------------------------"
    echo "系统每分钟会检测实际流量是否达到阈值，达到后会自动执行指令！"
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

# Setup cron job
setup_cron() {
  (crontab -l ; echo "* * * * * $HOME/liuliang.sh check") | crontab -
  (crontab -l ; echo "1 1 $cz_day * * reboot") | crontab -
  echo "定时任务已设置"
}

# Remove cron job
remove_cron() {
  crontab -l | grep -v "$HOME/liuliang.sh check" | crontab -
  crontab -l | grep -v "reboot" | crontab -
  echo "定时任务已移除"
}

main_menu
