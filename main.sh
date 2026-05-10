#!/bin/bash

# 设置颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# 显示暂停，按任意键继续，字体设置为绿色
pause() {
    echo -e "${GREEN}操作完成，按任意键继续...${NC}"
    read -n 1 -s -r  # 等待用户按下任意键
    echo
}

# 欢迎信息
echo -e "${GREEN}"大黄鹰-Linux服务器运维工具箱，是一款部署在github上开源的脚本工具，旨在为你提供简便的运维解决方案。"${NC}"
echo -e "脚本链接： https://github.com/dahuangying/dhy-box"

# 显示菜单
show_menu() {
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}  大黄鹰-Linux服务器运维工具箱${NC}"
    echo -e "欢迎使用本脚本，请根据菜单选择操作："
    echo -e "${GREEN}==================================${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 系统基础"
    echo "5. 系统工具"	
    echo "6. 应用市场"
    echo "7. Docker 管理"
    echo "8. 快捷方式"	
    echo "9. 更新程序"		
    echo "10. 卸载程序"
    echo "0. 退出"
    read -p "请输入选项编号: " choice
    case $choice in
        1)
            show_system_info
            ;;
        2)
            system_update
            ;;
        3)
            system_cleanup
            ;;
        4)
            bash linuxbox/system.sh
            ;;
        5)
            bash linuxbox/base.sh
            ;;		
        6)
            bash linuxbox/network.sh
            ;;
        7)
            bash linuxbox/docker.sh
            ;;
        8)
            menu_ln_manager
            ;;
        9)
            update_toolbox
            ;;			
        10)
            full_uninstall
            ;;
        0)
            echo "感谢使用大黄鹰-Linux服务器运维工具箱！"
            exit 0
            ;;
        *)
            echo "无效输入，请重试。"
            ;;
    esac
}

# 1. 显示系统信息
show_system_info() {
    
    # 获取主网络接口
    NET_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
    [ -z "$NET_IF" ] && NET_IF="eth0"

    echo -e "\n${GREEN}============ 系统信息查询 ============${NC}"
    
    # 1. 基础信息
    echo -e "${YELLOW}◆ 基础信息${NC}"
    echo "主机名: $(hostname)"
    echo "系统版本: $(lsb_release -d | cut -f2- 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "内核版本: $(uname -r)"
    echo "系统时间: $(date +"%Y-%m-%d %T %Z")"
    echo "运行时长: $(uptime -p)"
    
    # 2. CPU信息
    echo -e "\n${YELLOW}◆ CPU信息${NC}"
    echo "架构: $(uname -m)"
    echo "型号: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "核心数: $(nproc)核"
    echo "平均频率: $(lscpu | grep 'CPU MHz' | cut -d: -f2 | xargs) MHz"
    echo "占用率: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
    echo "系统负载: $(uptime | awk -F'load average: ' '{print $2}')"
    
    # 3. 内存信息
    echo -e "\n${YELLOW}◆ 内存信息${NC}"
    free -h | awk '/Mem/{printf "物理内存: %s/%s (可用: %s)\n", $3, $2, $7}'
    free -h | awk '/Swap/{printf "交换分区: %s/%s\n", $3, $2}'
    
    # 4. 磁盘信息
    echo -e "\n${YELLOW}◆ 存储信息${NC}"
    echo "根分区使用率: $(df -h / | awk 'NR==2{print $5}')"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -v loop
    echo -e "\n挂载点使用情况:"
    df -hT | grep -v tmpfs | awk '{printf "%-20s %-10s %-10s %-10s\n", $7, $2, $6, $5}'
    
    # 5. 网络信息（重点增强部分）
    echo -e "\n${YELLOW}◆ 网络信息${NC}"
    echo "主接口: $NET_IF"
    echo "内网IP: $(hostname -I | awk '{print $1}')"
    echo "公网IP: $(curl -s ipinfo.io/ip)"
    echo "运营商: $(curl -s ipinfo.io/org)"
    echo "地理位置: $(curl -s ipinfo.io/city), $(curl -s ipinfo.io/country)"
    echo "DNS: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')"
    echo "流量统计:"
    echo "  接收: $(numfmt --to=iec $(cat /sys/class/net/$NET_IF/statistics/rx_bytes))"
    echo "  发送: $(numfmt --to=iec $(cat /sys/class/net/$NET_IF/statistics/tx_bytes))"
    
    # ▼▼▼ 增强的网络算法信息 ▼▼▼
    echo -e "\n${BLUE}网络算法配置:${NC}"
    echo "TCP拥塞控制: $(sysctl -n net.ipv4.tcp_congestion_control)"
    echo "当前队列算法: $(sysctl -n net.core.default_qdisc)"
    echo "可用拥塞算法: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control)"
    echo "内存缓冲区:"
    echo "  TCP接收: $(sysctl -n net.ipv4.tcp_rmem | awk '{print $3/1024/1024"MB"}')"
    echo "  TCP发送: $(sysctl -n net.ipv4.tcp_wmem | awk '{print $3/1024/1024"MB"}')"
    # ▲▲▲ 新增内容结束 ▲▲▲
    
    # 6. 安全信息
    echo -e "\n${YELLOW}◆ 安全信息${NC}"
    echo "最后登录用户:"
    last -n 3 | head -n -2
    echo -e "\nSSH失败记录:"
    journalctl -u sshd | grep Failed | tail -n 3 2>/dev/null || echo "无记录"
    
    # 7. 硬件信息
    echo -e "\n${YELLOW}◆ 硬件信息${NC}"
    echo "主板型号: $(dmidecode -t baseboard | grep "Product Name" | cut -d: -f2 | xargs 2>/dev/null || echo "未知")"
    echo "BIOS版本: $(dmidecode -t bios | grep "Version" | cut -d: -f2 | xargs 2>/dev/null || echo "未知")"
    echo "GPU信息: $(lspci | grep -i vga | cut -d: -f3 | xargs 2>/dev/null || echo "未检测到独立显卡")"
    
    # 8. 容器/虚拟化
    echo -e "\n${YELLOW}◆ 运行环境${NC}"
    if [ -f /.dockerenv ]; then
        echo "Docker容器"
    elif systemd-detect-virt -q 2>/dev/null; then
        echo "虚拟化平台: $(systemd-detect-virt)"
    else
        echo "物理机"
    fi
    
    echo -e "${GREEN}================================${NC}"
    pause
}

# 2. 系统更新
system_update() {
    local NEED_REBOOT=false
    local KERNEL_REBOOT_FILE="/var/run/reboot-required.pkgs"
    local REBOOT_REQUIRED_FILE="/var/run/reboot-required"

    echo -e "\n${GREEN}=== 系统更新开始 ===${NC}"
	
	    # ====================== 【新增：检查是否需要更新】 ======================
    echo -e "${YELLOW}正在检查系统更新状态...${NC}"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            debian|ubuntu) apt update -qq >/dev/null 2>&1 && COUNT=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l) ;;
            centos|rhel) yum check-update -q >/dev/null 2>&1; COUNT=$? ;;
        esac
    fi
    [ -z "$COUNT" ] && COUNT=1
    if [ "$COUNT" -le 0 ] || [ "$COUNT" -eq 1 ]; then
        echo -e "${GREEN}系统已是最新版本，无需更新！${NC}"
        pause
        return 0
    fi
    echo -e "${GREEN}检测到可更新包，开始执行更新...${NC}"
    # ====================== 【新增结束】 ======================

    # 系统检测
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            debian|ubuntu)
                echo -e "${BLUE}[${PRETTY_NAME}] 更新中...${NC}"
                
                # 记录当前内核版本
                CURRENT_KERNEL=$(uname -r)
                
                # 执行更新
                if ! sudo apt update; then
                    echo -e "${RED}更新软件源失败${NC}"
                    return 1
                fi
                
                # 执行服务器标准完整升级（内核+依赖+安全更新）
                sudo apt full-upgrade -y
                sudo apt autoremove -y
				
                # 检查是否需要重启（更精确的判断）
                if [ -f "$REBOOT_REQUIRED_FILE" ] || \
                   [ -f "$KERNEL_REBOOT_FILE" ] || \
                   [ "$(sudo needrestart -b 2>/dev/null | grep -c 'NEEDRESTART-KERNEL')" -gt 0 ]; then
                    NEED_REBOOT=true
                fi
                
                # 检查内核是否更新
                NEW_KERNEL=$(ls -t /boot/vmlinuz-* | head -n1 | sed 's/.*vmlinuz-//')
                if [ "$NEW_KERNEL" != "$CURRENT_KERNEL" ]; then
                    echo -e "${YELLOW}内核已更新: ${CURRENT_KERNEL} → ${NEW_KERNEL}${NC}"
                    NEED_REBOOT=true
                fi
                ;;

            centos|rhel)
                echo -e "${BLUE}[${PRETTY_NAME}] 更新中...${NC}"
                # 记录当前内核
                CURRENT_KERNEL=$(uname -r)
                
                # 执行更新
                sudo yum update --security -y
                
                # 检查内核是否更新
                NEW_KERNEL=$(rpm -q kernel | tail -n1 | sed 's/kernel-//')
                if [ "$NEW_KERNEL" != "$CURRENT_KERNEL" ]; then
                    echo -e "${YELLOW}内核已更新: ${CURRENT_KERNEL} → ${NEW_KERNEL}${NC}"
                    NEED_REBOOT=true
                fi
                
                # 检查其他需要重启的更新
                if sudo needs-restarting -r >/dev/null 2>&1; then
                    NEED_REBOOT=true
                fi
                ;;

            arch)
                echo -e "${BLUE}[Arch] 更新中...${NC}"
                # Arch通常不需要专门重启
                sudo pacman -Syu --noconfirm
                ;;
        esac

        # 通用Flatpak/Snap更新
        command -v flatpak >/dev/null && flatpak update -y
        command -v snap >/dev/null && sudo snap refresh
    fi

    # 更新后处理
    echo -e "\n${GREEN}=== 更新完成 ===${NC}"
    
    # 更精确的重启判断
    if $NEED_REBOOT; then
        echo -e "${YELLOW}系统需要重启以完成更新${NC}"
        echo -e "以下更新需要重启:"
        [ -f "$KERNEL_REBOOT_FILE" ] && cat "$KERNEL_REBOOT_FILE" | sed 's/^/• /'
        [ -f "$REBOOT_REQUIRED_FILE" ] && cat "$REBOOT_REQUIRED_FILE" | sed 's/^/• /'
        
        read -p $'\033[33m是否立即重启？(y/N): \033[0m' choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}系统将在5秒后重启...${NC}"
            # 清除重启标记
            sudo rm -f "$REBOOT_REQUIRED_FILE" "$KERNEL_REBOOT_FILE" 2>/dev/null
            sleep 5
            sudo reboot
        else
            echo -e "${YELLOW}请稍后手动执行 reboot 命令${NC}"
        fi
    else
        echo -e "${CYAN}无需重启，所有更新已实时生效${NC}"
    fi

    pause
}

# 3. 系统清理
system_cleanup() {

    # 安全清理函数
    safe_clean() {
        local path="$1"
        [[ "$path" == "/" ]] && { echo -e "${RED}错误：禁止操作根目录${NC}"; return 1; }
        [ -e "$path" ] || { echo -e "${YELLOW}警告：路径不存在 [$path]${NC}"; return 1; }
        return 0
    }

    # 智能重启检测
    check_reboot() {
        local reboot_marker="/var/run/reboot-required"
        local kernel_changed=$( [ "$(uname -r)" != "$(ls -t /boot/vmlinuz-* 2>/dev/null | head -n1 | sed 's/.*vmlinuz-//')" ] && echo 1 )
        
        if [ -f "$reboot_marker" ] || [ -n "$kernel_changed" ]; then
            echo -e "\n${RED}⚠️ 需要重启以完成以下更新：${NC}"
            [ -f "$reboot_marker" ] && cat "$reboot_marker" | sed 's/^/  /'
            [ -n "$kernel_changed" ] && echo -e "  ${YELLOW}内核已更新${NC}"
            return 0
        fi
        return 1
    }

    # 主清理流程
    echo -e "\n${GREEN}=== 系统清理开始 ===${NC}"
    local start_time=$(date +%s)
    local disk_before=$(df -h / | awk 'NR==2{print $4}')

    # 按发行版清理
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            debian|ubuntu)
                echo -e "${CYAN}◆ ${PRETTY_NAME} 系统清理${NC}"
                sudo apt autoremove --purge -y
                sudo apt clean
                ;;
            centos|rhel)
                echo -e "${CYAN}◆ ${PRETTY_NAME} 系统清理${NC}"
                if command -v dnf >/dev/null; then
                    sudo dnf autoremove -y
                    sudo dnf clean all
                else
                    sudo yum autoremove -y
                    sudo yum clean all
                fi
                ;;
        esac
    fi

    # 通用清理
    echo -e "\n${CYAN}◆ 临时文件清理${NC}"
    safe_clean "/tmp" && sudo find /tmp -type f -atime +1 -delete
    safe_clean "/var/tmp" && sudo find /var/tmp -type f -atime +7 -delete

    echo -e "\n${CYAN}◆ 日志清理${NC}"
    sudo journalctl --vacuum-time=3d 2>/dev/null
    safe_clean "/var/log" && sudo find /var/log -type f \( -name "*.gz" -o -name "*.old" \) -mtime +7 -delete

    # 结果统计
    local disk_after=$(df -h / | awk 'NR==2{print $4}')
    echo -e "\n${GREEN}✓ 清理完成 [耗时: $(( $(date +%s) - start_time ))秒]${NC}"
    echo -e "空间变化: ${disk_before} → ${disk_after}"

    # 重启建议
    if check_reboot; then
        read -p "$(echo -e "${YELLOW}是否立即重启？(y/N): ${NC}")" choice
        if [[ "$choice" =~ ^[Yy] ]]; then
            echo -e "${GREEN}系统将在5秒后重启...${NC}"
            sleep 5
            sudo reboot
        fi
    fi
    pause
}

#8.快捷方式软链接管理 
menu_ln_manager() {
local SRC_FILE="/root/linuxbox/main.sh"
    local LINK_DIR="/usr/local/bin"

    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：必须使用 root 权限运行${NC}"
        read -p "按回车返回..."
        return
    fi

    while true; do
        clear
        echo -e "${GREEN}=== 快捷方式管理 =====${NC}"
        echo "1. 创建快捷键（默认名称：dy）"
        echo "2. 查看快捷键"
        echo "3. 删除快捷键"
        echo "0. 退出"
        echo -e "${GREEN}======================${NC}"
        read -p "请选择操作编号：" opt

        case $opt in
            1)
                read -p "请输入快捷键名称【默认: dy 直接回车使用】：" link_name
                [ -z "$link_name" ] && link_name="dy"
                local link_full="${LINK_DIR}/${link_name}"

                if [ ! -f "${SRC_FILE}" ]; then
                    echo -e "${RED}源文件不存在：${SRC_FILE}${NC}"
                    read -p "按回车键返回..."
                    continue
                fi

                chmod +x "${SRC_FILE}"

                if [ -L "${link_full}" ]; then
                    echo -e "${YELLOW}名称已被占用！${NC}"
                    echo "当前指向：$(readlink "${link_full}")"
                    echo "1.覆盖 2.删除重建 3.取消"
                    read -p "请选择：" c_opt
                    case $c_opt in
                        1) ln -sf "${SRC_FILE}" "${link_full}" ;;
                        2) rm -f "${link_full}" && ln -s "${SRC_FILE}" "${link_full}" ;;
                        3) echo "已取消" ;;
                        *) echo "输入错误" ;;
                    esac
                else
                    ln -s "${SRC_FILE}" "${link_full}"
                fi
                echo -e "${GREEN}操作完成！全局命令：${link_name}${NC}"
                read -p "按回车键返回..."
                ;;

            2)
                echo -e "\n${GREEN}===== ${LINK_DIR} 快捷键列表 =====${NC}"
                ls -l "${LINK_DIR}" | grep "\->"
                read -p "按回车键返回..."
                ;;

            3)
                read -p "请输入要删除的快捷键名称：" link_name
                local link_full="${LINK_DIR}/${link_name}"
                if [ ! -L "${link_full}" ]; then
                    echo "快捷键不存在"
                else
                    read -p "确定删除 ${link_name} ?(y/n) " yn
                    [[ "$yn" == [yY] ]] && rm -f "${link_full}" && echo "删除成功"
                fi
                read -p "按回车键返回..."
                ;;

            0) break ;;
            *) echo -e "${RED}输入无效${NC}"; read -p "按回车键继续..." ;;
        esac
    done
}

# 9.更新工具箱
update_toolbox() {
    echo -e "\n${CYAN}程序更新后，进入主菜单...${NC}"
    rm -rf ./linuxbox >/dev/null 2>&1
    source "$0"
}

# 10.完整卸载工具箱
full_uninstall() {
    # 第一步：确认
    echo -e "${GREEN}确定要卸载大黄鹰运维工具箱吗？（y/n）${NC}"
    read confirmation
    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
        echo -e "${GREEN}已取消卸载${NC}"
        return
    fi

    # 第二步：删除 linuxbox 目录（连目录带文件全删）
    echo -e "${GREEN}正在卸载所有模块...${NC}"
    rm -rf linuxbox
    
    # ===================== 【清理自定义快捷键】 =====================
    echo -e "${GREEN}正在清理自定义快捷键...${NC}"
    TARGET="/root/linuxbox/main.sh"
    for link in /usr/local/bin/*; do
        if [[ -L "$link" && "$(readlink "$link")" == "$TARGET" ]]; then
            rm -f "$link"
        fi
    done


    # 完成提示
    echo -e "${GREEN}✅ 大黄鹰运维工具箱已完全卸载完成！${NC}"
    exit 0
}

# 模块静默拉取下载
MODULES_DIR="./linuxbox"

download_module() {
    MODULE_NAME=$1
    MODULE_URL=$2

    # 如果模块已存在且大小>0，跳过下载
    if [ -s "$MODULES_DIR/$MODULE_NAME" ]; then
        return 0
    fi

    # 静默下载（不显示进度，仅错误输出）
    if ! curl -fsSL "$MODULE_URL" -o "$MODULES_DIR/$MODULE_NAME" 2>/dev/null; then
        echo -e "${RED}错误: 模块 $MODULE_NAME 下载失败${NC}" >&2
        return 1
    fi

    # 验证下载完整性（至少非空文件）
    if [ ! -s "$MODULES_DIR/$MODULE_NAME" ]; then
        echo -e "${RED}错误: 下载的模块 $MODULE_NAME 为空${NC}" >&2
        rm -f "$MODULES_DIR/$MODULE_NAME"
        return 1
    fi
}

# 初始化模块目录
mkdir -p "$MODULES_DIR"

# 静默下载所有模块（无输出提示）
download_module "system.sh" "https://raw.githubusercontent.com/dahuangying/dhy-box/main/linuxbox/system.sh"
download_module "docker.sh" "https://raw.githubusercontent.com/dahuangying/dhy-box/main/linuxbox/docker.sh"
download_module "network.sh" "https://raw.githubusercontent.com/dahuangying/dhy-box/main/linuxbox/network.sh"
download_module "base.sh" "https://raw.githubusercontent.com/dahuangying/dhy-box/main/linuxbox/base.sh"
download_module "main.sh" "https://raw.githubusercontent.com/dahuangying/dhy-box/main/main.sh"

# 为下载的模块赋予执行权限
chmod +x "$MODULES_DIR"/*

# 显示暂停，按任意键继续，字体设置为绿色
pause() {
    echo -e "${GREEN}操作完成，按任意键继续...${NC}"
    read -n 1 -s -r  # 等待用户按下任意键
    echo
}

# 主程序入口
while true; do
    show_menu
done  # 这里需要加上 done 来结束 while 循环
