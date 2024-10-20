#!/bin/bash

# 脚本说明
# 这是一个用于监控网络流量的脚本，当流量超过指定阈值时，可以执行指定的命令。
# 该脚本会定期检查流量，并在必要时执行命令。

# 定义常量
脚本地址="https://github.com/mi1314cat/sary-hysteria2.catmi/raw/refs/heads/main/liuliang.sh"
配置文件="$HOME/流量监控.conf"
默认进站阈值=95
默认出站阈值=95
默认重置日期=1
默认命令="reboot"

# 检查并下载脚本文件
if [ ! -f "$配置文件" ]; then
  curl -fsSL "$脚本地址" -o "$HOME/liuliang.sh" || {
    echo "下载脚本文件失败"
    exit 1
  }
fi


# 设置脚本文件执行权限
chmod +x "$HOME/liuliang.sh" || {
  echo "设置脚本文件执行权限失败"
  exit 1
}

# 创建脚本文件的符号链接
ln -s "$HOME/liuliang.sh" "$HOME/liu" || {
  echo "创建符号链接失败"
  exit 1
}

# 读取配置文件
读取配置() {
  if [ -f "$配置文件" ]; then
    source "$配置文件"
  else
    echo "rx_threshold_gb=$默认进站阈值" > "$配置文件"
    echo "tx_threshold_gb=$默认出站阈值" >> "$配置文件"
    echo "cz_day=$默认重置日期" >> "$配置文件"
    echo "command=\"$默认命令\"" >> "$配置文件"
    source "$配置文件"
  fi
}

# 写入配置文件
写入配置() {
  echo "rx_threshold_gb=$rx_threshold_gb" > "$配置文件"
  echo "tx_threshold_gb=$tx_threshold_gb" >> "$配置文件"
  echo "cz_day=$cz_day" >> "$配置文件"
  echo "command=\"$command\"" >> "$配置文件"
}

# 获取网络流量统计
获取流量() {
  网卡=$(ls /sys/class/net | grep -v 'lo' | head -n 1)
  if [ -z "$网卡" ]; then
    echo "获取网络接口失败"
    exit 1
  fi

  rx_bytes=$(cat "/sys/class/net/$网卡/statistics/rx_bytes")
  tx_bytes=$(cat "/sys/class/net/$网卡/statistics/tx_bytes")

  echo "$((rx_bytes / 1024 / 1024 / 1024))" > ~/当前进站流量.txt
  echo "$((tx_bytes / 1024 / 1024 / 1024))" > ~/当前出站流量.txt
}

# 输出网络流量统计
输出状态() {
  统计信息=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
    NR > 2 { rx_total += $2; tx_total += $10 }
    END {
      rx_units = "字节";
      tx_units = "字节";
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

      if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
      if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
      if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

      print("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
    }' /proc/net/dev)
  echo "$统计信息"
}

# 检查网络流量
检查流量() {
  当前进站流量=$(cat ~/当前进站流量.txt)
  当前出站流量=$(cat ~/当前出站流量.txt)
  if [ "$当前进站流量" -ge "$rx_threshold_gb" ] || [ "$当前出站流量" -ge "$tx_threshold_gb" ]; then
    echo "流量超过阈值，执行命令"
    执行命令
  fi
}

# 执行命令
执行命令() {
  "$command"
}

# 主菜单
主菜单() {
  while true; do
    clear
    echo "流量监控和命令执行功能"
    echo "------------------------------------------------"
    echo "当前流量统计"
    获取流量
    输出状态
    echo "当前进站流量: $(cat ~/当前进站流量.txt) GB"
    echo "当前出站流量: $(cat ~/当前出站流量.txt) GB"
    echo "------------------------------------------------"
    读取配置
    echo "当前设置的进站阈值为: $rx_threshold_gb GB"
    echo "当前设置的出站阈值为: $tx_threshold_gb GB"
    echo "当前流量重置日期: $cz_day"
    echo "当前执行命令: $command"
    echo "------------------------------------------------"
    read -e -p "选择操作: 1. 设置阈值 2. 设置命令 3. 启用监控 4. 停用监控 0. 退出: " choice

    case "$choice" in
      1)
        read -e -p "输入进站阈值（单位为GB）: " rx_threshold_gb
        read -e -p "输入出站阈值（单位为GB）: " tx_threshold_gb
        read -e -p "输入流量重置日期（默认每天重置）: " cz_day
        cz_day=${cz_day:-1}
        写入配置
        设置定时任务
        echo "阈值已设置"
        ;;
      2)
        read -e -p "输入要执行的命令: " command
        写入配置
        echo "执行命令已设置"
        ;;
      3)
        设置定时任务
        echo "已启用流量监控功能"
        ;;
      4)
        删除定时任务
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
设置定时任务() {
  (crontab -l ; echo "* * * * * $HOME/liuliang.sh 检查流量") | crontab -
  (crontab -l ; echo "0 0 $cz_day * * $command") | crontab -
  echo "已设置定时任务"
}

# 删除定时任务
删除定时任务() {
  crontab -l | grep -v "$HOME/liuliang.sh 检查流量" | crontab -
  crontab -l | grep -v "$command" | crontab -
  echo "已删除定时任务"
}

主菜单
