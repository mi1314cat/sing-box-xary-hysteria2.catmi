#!/bin/bash

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 设置文件路径
TRAFFIC_FILE="/var/log/traffic.log"
LIMIT_FILE="/etc/traffic_limit.conf"
RESET_METHOD_FILE="/etc/traffic_reset_method.conf"
CURRENT_TRAFFIC_FILE="/var/log/current_traffic.log"
SCRIPT_ON_LIMIT_FILE="/etc/traffic_script.conf"
SERVICE_FILE="/etc/systemd/system/traffic-monitor.service"
SCRIPT_PATH="/usr/local/bin/traffic-monitor.sh"

# 初始化文件
initialize_files() {
    echo -e "${GREEN}初始化文件...${PLAIN}"
    touch "$TRAFFIC_FILE" "$LIMIT_FILE" "$RESET_METHOD_FILE" "$CURRENT_TRAFFIC_FILE" "$SCRIPT_ON_LIMIT_FILE"
    if [ ! -s "$LIMIT_FILE" ]; then
        echo "500000" > "$LIMIT_FILE"  # 默认限制：500GB
    fi
    if [ ! -s "$RESET_METHOD_FILE" ]; then
        echo "3" > "$RESET_METHOD_FILE"  # 默认重置方法：3（从不）
    fi
    if [ ! -s "$SCRIPT_ON_LIMIT_FILE" ]; then
        echo "" > "$SCRIPT_ON_LIMIT_FILE"  # 默认脚本：无
    fi
    echo -e "${GREEN}文件初始化完成。${PLAIN}"
}

# 设置流量重置方法
set_reset_method() {
    echo -e "${GREEN}流量重置方法${PLAIN}
  ----------------------
  ${GREEN}1.${PLAIN} 每月第一天
  ${GREEN}2.${PLAIN} 每30天
  ${GREEN}3.${PLAIN} 从不
  ${GREEN}0.${PLAIN} 返回"
    read -p "选择重置方法: " method
    case $method in
        1) echo "1" > "$RESET_METHOD_FILE" ;;
        2) echo "2" > "$RESET_METHOD_FILE" ;;
        3) echo "3" > "$RESET_METHOD_FILE" ;;
        0) return ;;
        *) echo "无效的选择" ;;
    esac
    # 更新cron任务
    update_cron_job
}

# 更新cron任务
update_cron_job() {
    reset_method=$(cat "$RESET_METHOD_FILE")
    crontab -l > /tmp/crontab.bak
    if [ "$reset_method" -eq 1 ]; then
        # 每月第一天重置流量
        echo "0 0 1 * * /bin/bash $SCRIPT_PATH reset_traffic" >> /tmp/crontab.bak
    elif [ "$reset_method" -eq 2 ]; then
        # 每30天重置流量
        echo "0 0 * * * /bin/bash $SCRIPT_PATH reset_traffic" >> /tmp/crontab.bak
    else
        # 从不重置流量
        sed -i '/reset_traffic/d' /tmp/crontab.bak
    fi
    crontab /tmp/crontab.bak
    rm /tmp/crontab.bak
    echo -e "${GREEN}Cron任务已更新。${PLAIN}"
}

# 重置流量
reset_traffic() {
    echo "0" > "$CURRENT_TRAFFIC_FILE"
    echo -e "${GREEN}流量已重置。${PLAIN}"
}

# 检查流量限制
check_traffic_limit() {
    limit=$(cat "$LIMIT_FILE")
    current_traffic=$(cat "$CURRENT_TRAFFIC_FILE")
    if [ "$current_traffic" -ge "$limit" ]; then
        echo -e "${GREEN}流量限制已达到，执行脚本...${PLAIN}"
        script_path=$(cat "$SCRIPT_ON_LIMIT_FILE")
        if [ -n "$script_path" ]; then
            bash "$script_path"
        fi
    fi
}

# 设置流量限制
set_traffic_limit() {
    read -p "输入新的流量限制 (例如 500): " new_limit
    echo "$((new_limit * 1000))" > "$LIMIT_FILE"
    echo -e "${GREEN}流量限制已设置为: ${new_limit}GB${PLAIN}"
}

# 设置流量达到限制时执行的脚本
set_script_on_limit() {
    read -p "输入流量达到限制时要执行的脚本路径: " script_path
    echo "$script_path" > "$SCRIPT_ON_LIMIT_FILE"
    echo -e "${GREEN}已设置脚本: $script_path${PLAIN}"
}

# 获取流量管理服务状态
get_service_status() {
    if systemctl is-active --quiet traffic-monitor.service; then
        echo "${GREEN}已启动${PLAIN}"
    else
        echo "${YELLOW}未启动${PLAIN}"
    fi
}

# 获取流量限制
get_traffic_limit() {
    limit=$(cat "$LIMIT_FILE")
    if [ "$limit" -lt 1000 ]; then
        echo "$limit MB"
    else
        echo "$((limit / 1000)) GB"
    fi
}

# 获取已使用的流量
get_current_traffic() {
    current_traffic=$(cat "$CURRENT_TRAFFIC_FILE")
    if [ "$current_traffic" -lt 1000 ]; then
        echo "$current_traffic MB"
    else
        echo "$((current_traffic / 1000)) GB"
    fi
}

# 获取剩余流量
get_remaining_traffic() {
    limit=$(cat "$LIMIT_FILE")
    current_traffic=$(cat "$CURRENT_TRAFFIC_FILE")
    remaining=$((limit - current_traffic))
    if [ "$remaining" -lt 1000 ]; then
        echo "$remaining MB"
    else
        echo "$((remaining / 1000)) GB"
    fi
}

# 创建系统服务
create_service() {
    echo -e "${GREEN}创建系统服务...${PLAIN}"
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Traffic Monitoring Service
After=network.target

[Service]
ExecStart=/bin/bash /usr/local/bin/traffic-monitor.sh check_traffic_limit
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable traffic-monitor.service
    echo -e "${GREEN}系统服务创建并启用完成。${PLAIN}"
}

# 创建快捷方式
create_alias() {
    echo -e "${GREEN}创建快捷方式...${PLAIN}"
    echo "alias catmiliu='bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/liuliang.sh)'" >> ~/.bashrc
    source ~/.bashrc
    echo -e "${GREEN}快捷方式创建完成。${PLAIN}"
}

# 卸载脚本
uninstall_script() {
    echo -e "${GREEN}卸载脚本...${PLAIN}"
    # 停止并禁用服务
    systemctl stop traffic-monitor.service
    systemctl disable traffic-monitor.service
    rm -f "$SERVICE_FILE"

    # 删除cron任务
    crontab -l > /tmp/crontab.bak
    sed -i '/reset_traffic/d' /tmp/crontab.bak
    crontab /tmp/crontab.bak
    rm /tmp/crontab.bak

    # 删除文件
    rm -f "$TRAFFIC_FILE" "$LIMIT_FILE" "$RESET_METHOD_FILE" "$CURRENT_TRAFFIC_FILE" "$SCRIPT_ON_LIMIT_FILE"

    # 删除快捷方式
    sed -i '/catmiliu/d' ~/.bashrc
    source ~/.bashrc

    echo -e "${GREEN}脚本已卸载。${PLAIN}"
}

# 主菜单
main_menu() {
    echo -e "${GREEN}流量管理脚本${PLAIN}
  ----------------------
  流量管理服务状态: $(get_service_status)
  流量限制: $(get_traffic_limit)
  已使用的流量: $(get_current_traffic)
  剩余流量: $(get_remaining_traffic)
  ----------------------
  ${GREEN}1.${PLAIN} 初始化文件
  ${GREEN}2.${PLAIN} 设置流量限制
  ${GREEN}3.${PLAIN} 设置流量重置方法
  ${GREEN}4.${PLAIN} 设置流量达到限制时执行的脚本
  ${GREEN}5.${PLAIN} 检查流量限制
  ${GREEN}6.${PLAIN} 启动流量管理服务
  ${GREEN}7.${PLAIN} 停止流量管理服务
  ${GREEN}8.${PLAIN} 重启流量管理服务
  ${GREEN}9.${PLAIN} 手动重置流量
  ${GREEN}10.${PLAIN} 卸载脚本
  ${GREEN}0.${PLAIN} 退出"
    read -p "选择操作: " choice
    case $choice in
        1) initialize_files ;;
        2) set_traffic_limit ;;
        3) set_reset_method ;;
        4) set_script_on_limit ;;
        5) check_traffic_limit ;;
        6) 
            echo -e "${GREEN}启动流量管理服务...${PLAIN}"
            systemctl start traffic-monitor.service
            if systemctl is-active --quiet traffic-monitor.service; then
                echo -e "${GREEN}流量管理服务已启动。${PLAIN}"
            else
                echo -e "${RED}启动流量管理服务失败。${PLAIN}"
                journalctl -u traffic-monitor.service -n 10
            fi
            ;;
        7) 
            echo -e "${GREEN}停止流量管理服务...${PLAIN}"
            systemctl stop traffic-monitor.service
            if systemctl is-active --quiet traffic-monitor.service; then
                echo -e "${RED}停止流量管理服务失败。${PLAIN}"
            else
                echo -e "${GREEN}流量管理服务已停止。${PLAIN}"
            fi
            ;;
        8) 
            echo -e "${GREEN}重启流量管理服务...${PLAIN}"
            systemctl restart traffic-monitor.service
            if systemctl is-active --quiet traffic-monitor.service; then
                echo -e "${GREEN}流量管理服务已重启。${PLAIN}"
            else
                echo -e "${RED}重启流量管理服务失败。${PLAIN}"
                journalctl -u traffic-monitor.service -n 10
            fi
            ;;
        9) reset_traffic ;;
        10) uninstall_script ;;
        0) exit ;;
        *) echo "无效的选择" ;;
    esac
}

# 确保脚本路径正确并具有可执行权限
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${GREEN}下载并复制脚本到 /usr/local/bin...${PLAIN}"
    sudo curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/liuliang.sh -o "$SCRIPT_PATH"
    sudo chmod +x "$SCRIPT_PATH"
    echo -e "${GREEN}脚本已下载并设置可执行权限。${PLAIN}"
fi

# 自动执行初始化和创建系统服务
initialize_files
create_service
create_alias

# 主循环
while true; do
    main_menu
done
