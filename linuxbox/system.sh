#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误：此脚本必须以root权限运行！${NC}" >&2
        exit 1
    fi
}

# 安全输入（可回车退出）
safe_input() {
    local prompt="$1"
    local var_name="$2"
    local is_password="${3:-n}"
    
    echo -ne "${YELLOW}${prompt}（直接回车取消）: ${NC}"
    if [ "$is_password" = "y" ]; then
        read -s "$var_name"
        echo
    else
        read "$var_name"
    fi
    
    [ -z "${!var_name}" ] && return 1
    return 0
}

# 安全确认函数
confirm_action() {
    local action=$1
    local target=$2
    echo -e "${RED}警告：即将执行 ${action} 操作目标：${YELLOW}${target}${NC}"
    read -p "确认执行？(y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]] && return 0 || return 1
}

# 等待任意键继续
wait_key() {
    echo -e "\n${GREEN}操作完成，按任意键继续...${NC}"
    read -n 1 -s -r
}

# SSH服务管理
restart_ssh_service() {
    if systemctl list-unit-files | grep -q 'sshd.service'; then
        systemctl restart sshd
    elif systemctl list-unit-files | grep -q 'ssh.service'; then
        systemctl restart ssh
    elif [ -f /etc/init.d/ssh ]; then
        /etc/init.d/ssh restart
    else
        echo -e "${RED}无法确定SSH服务名称，请手动重启！${NC}"
        return 1
    fi
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}大黄鹰-Linux服务器运维工具箱菜单 - 系统基础${NC}"
    echo -e "欢迎使用本脚本，请根据菜单选择操作："
    echo -e "${GREEN}====================================================${NC}"	
	echo -e "1 . 重启服务器"
    echo -e "${BLUE}---------------------------------------${NC}"
    echo -e "2. 查看端口占用状态"
    echo -e "3. 查看防火墙状态"
    echo -e "4. 关闭防火墙"
    echo -e "5. 开启防火墙"
    echo -e "6. 开放指定端口"
    echo -e "7. 关闭指定端口"	
    echo -e "${BLUE}---------------------------------------${NC}"	
    echo -e "8.  文件权限设置"	
    echo -e "${BLUE}---------------------------------------${NC}"
    echo -e "9. 创建目录"
    echo -e "10. 创建文件"
    echo -e "11. 删除目录/文件"
    echo -e "12. 编辑文件"
    echo -e "13. 查找文件/目录"
    echo -e "${BLUE}---------------------------------------${NC}"
    echo -e "0. 退出"
    echo -n "请输入选项数字: "
}

# 主循环
main() {
    check_root
    while true; do
        show_menu
        read option
        case $option in
             1) reboot_server ;;
             2) show_port_status ;;
			 3) show_firewall_status ;; 				
             4) stop_firewall ;;
             5) start_firewall ;;
             6) open_specific_port ;;
             7) close_specific_port ;;
             8) file_permission_settings ;;
             9) create_directory ;;
            10) create_file ;;
            11) delete_target ;;
            12) edit_file ;;
            13) search_files ;;
            0) echo -e "${GREEN}脚本已退出${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项！${NC}"; sleep 1 ;;
        esac
    done
}



# 1. 重启服务器函数
reboot_server() {
    echo -e "\n${RED}=== 重启服务器 ===${NC}"
    echo -e "${YELLOW}警告：这将导致服务器立即重启！${NC}"
    
    # 确认操作
    read -p "确定要重启服务器吗？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}已取消重启操作${NC}"
        wait_key
        return
    fi

    # 倒计时提示
    for i in {5..1}; do
        echo -ne "${RED}服务器将在 ${i} 秒后重启...${NC}\033[0K\r"
        sleep 1
    done

    # 执行重启
    echo -e "\n${GREEN}正在重启服务器...${NC}"
    shutdown -r now
}

# 2. 查看端口占用状态
show_port_status() {
    echo -e "\n${YELLOW}=== 端口占用状态 ===${NC}"
    ss -tulnp
    wait_key
}

# 3. 查看防火墙状态
show_firewall_status() {
    echo -e "\n${YELLOW}=== 防火墙状态 ===${NC}"
    case $(detect_firewall) in
        ufw)
            ufw status verbose
            ;;
        firewalld)
            firewall-cmd --state 2>/dev/null && echo "firewalld 运行中"
            firewall-cmd --list-all 2>/dev/null
            ;;
        iptables)
            iptables -L -n
            ;;
        *)
            echo -e "${RED}未检测到防火墙${NC}"
            ;;
    esac
    wait_key
}

# 4. 关闭防火墙（同步关闭自启，保留全部规则）
stop_firewall() {
    echo -e "\n${RED}=== 关闭防火墙（保留所有规则） ===${NC}"
    case $(detect_firewall) in
        ufw)
            ufw disable
            ;;
        firewalld)
            systemctl stop firewalld
            systemctl disable firewalld
            ;;
        iptables)
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            echo -e "${YELLOW}iptables 已临时放行所有，规则保留${NC}"
            ;;
        *)
            echo -e "${YELLOW}未检测到防火墙${NC}"
            wait_key
            return
            ;;
    esac
    echo -e "${GREEN}防火墙已关闭 + 开机自启已关闭 + 规则全部保留${NC}"
    wait_key
}

# 5. 开启防火墙（同步开启自启，兜底放行22，不动原有规则）
start_firewall() {
    echo -e "\n${GREEN}=== 开启防火墙（兜底放行22） ===${NC}"
    local ft=$(detect_firewall)
    case $ft in
        ufw)
            ufw enable
            ufw allow 22/tcp
            ;;
        firewalld)
            systemctl enable --now firewalld
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null
            echo -e "${YELLOW}iptables 启动并确保22端口开放${NC}"
            ;;
        *)
            echo -e "${RED}未检测到防火墙${NC}"
            wait_key
            return
            ;;
    esac
    echo -e "${GREEN}防火墙已开启 + 自启已开启 + 22端口已确保放行${NC}"
    wait_key
}

# 6. 开放指定端口（需开启防火墙，支持多端口）
open_specific_port() {
    echo -e "\n${YELLOW}=== 开放指定端口（支持 80,443 格式） ===${NC}"

    if ! is_firewall_active; then
        echo -e "${RED}错误：请先开启防火墙！${NC}"
        wait_key
        return
    fi

    if ! safe_input "输入端口号(逗号分隔)" "ports"; then
        wait_key
        return
    fi

    if ! safe_input "协议类型(tcp/udp，默认tcp)" "proto"; then
        proto="tcp"
    fi
    proto=${proto:-tcp}

    IFS=',' read -ra arr <<< "$ports"
    for p in "${arr[@]}"; do
        p=$(trim "$p")
        if [[ ! $p =~ ^[0-9]+$ ]] || [[ $p -lt 1 || $p -gt 65535 ]]; then
            echo -e "${RED}跳过无效端口：$p${NC}"
            continue
        fi

        case $(detect_firewall) in
            ufw) ufw allow $p/$proto ;;
            firewalld)
                firewall-cmd --permanent --add-port=$p/$proto
                firewall-cmd --reload
                ;;
            iptables)
                iptables -A INPUT -p $proto --dport $p -j ACCEPT
                ;;
        esac
        echo -e "${GREEN}已开放：$p/$proto${NC}"
    done

    wait_key
}

# 7. 关闭指定端口（需开启防火墙，禁止关22+支持多端口）
close_specific_port() {
    echo -e "\n${YELLOW}=== 关闭指定端口（支持 80,443 格式） ===${NC}"

    if ! is_firewall_active; then
        echo -e "${RED}错误：请先开启防火墙！${NC}"
        wait_key
        return
    fi

    if ! safe_input "输入端口号(逗号分隔)" "ports"; then
        wait_key
        return
    fi

    if ! safe_input "协议类型(tcp/udp，默认tcp)" "proto"; then
        proto="tcp"
    fi
    proto=${proto:-tcp}

    IFS=',' read -ra arr <<< "$ports"
    for p in "${arr[@]}"; do
        p=$(trim "$p")
        if [[ ! $p =~ ^[0-9]+$ ]]; then
            echo -e "${RED}跳过无效端口：$p${NC}"
            continue
        fi

        if [ "$p" = "22" ]; then
            echo -e "${RED}22 端口禁止关闭！${NC}"
            continue
        fi

        case $(detect_firewall) in
            ufw)
                ufw delete allow $p/$proto 2>/dev/null
                ;;
            firewalld)
                firewall-cmd --permanent --remove-port=$p/$proto
                firewall-cmd --reload
                ;;
            iptables)
                iptables -D INPUT -p $proto --dport $p -j ACCEPT 2>/dev/null
                ;;
        esac
        echo -e "${GREEN}已关闭：$p/$proto${NC}"
    done

    wait_key
}

# ------------------------------
# 工具函数（直接放脚本末尾即可）
# ------------------------------
detect_firewall() {
    if command -v ufw &>/dev/null; then
        echo "ufw"
    elif command -v firewall-cmd &>/dev/null; then
        echo "firewalld"
    elif command -v iptables &>/dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

is_firewall_active() {
    local t=$(detect_firewall)
    case $t in
        ufw) [[ $(ufw status | head -n1) == *"active"* ]] ;;
        firewalld) firewall-cmd --state &>/dev/null ;;
        iptables) iptables -S | grep -q INPUT ;;
        *) return 1 ;;
    esac
}

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# 8. 文件权限设置
file_permission_settings() {
    while true; do
        clear
        echo -e "${GREEN}=== 文件权限设置 ===${NC}"
	    echo -e "1. drwxr-xr-x (777)"
        echo -e "2. rwxr-xr-x (755)"
	    echo -e "3. rwx------ (700)"
        echo -e "4. rw-r--r-- (644)"
		echo -e "5. rw------- (600)"
        echo -e "6. r-xr-xr-x (555)"
        echo -e "7. r-------- (400)"
        echo -e "0. 返回主菜单"
        
        if ! safe_input "请选择权限模式" "choice"; then
            return
        fi

        case $choice in
	        1) perm=777; desc="drwxr-xr-x (777)"; ;;
            2) perm=755; desc="rwxr-xr-x (755)"; ;;
	        3) perm=700; desc="rwx------ (700)"; ;;
            4) perm=644; desc="rw-r--r-- (644)"; ;;
			5) perm=600; desc="rw------- (600)"; ;;
            6) perm=555; desc="r-xr-xr-x (555)"; ;;
            7) perm=400; desc="r-------- (400)"; ;;
            0) return ;;
            *) echo -e "${RED}无效选择！${NC}"; sleep 1; continue ;;
        esac

        if ! safe_input "请输入文件/目录路径" "path"; then
            continue
        fi

        if [ ! -e "$path" ]; then
            echo -e "${RED}路径不存在！${NC}"
            sleep 1
            continue
        fi

        echo -e "即将设置: ${YELLOW}$path${NC} -> ${BLUE}$desc${NC}"
        if ! safe_input "确认修改？(y/n)" "confirm"; then
            continue
        fi

        if [ "$confirm" = "y" ]; then
            if [ -d "$path" ]; then
                find "$path" -type d -exec chmod $perm {} \; 2>/dev/null
                find "$path" -type f -exec chmod $perm {} \; 2>/dev/null
            else
                chmod $perm "$path"
            fi
            echo -e "${GREEN}权限设置成功！${NC}"
        else
            echo -e "${YELLOW}已取消操作${NC}"
        fi
        wait_key
    done
}

# 9. 创建目录
create_directory() {
    read -p "输入要创建的目录路径及目录名: " dirpath
    if [ -z "$dirpath" ]; then
        echo -e "${RED}路径不能为空！${NC}"
        return
    fi
    
    if confirm_action "创建目录" "$dirpath"; then
        if mkdir -p "$dirpath"; then
            echo -e "${GREEN}目录创建成功！${NC}"
            recommend_permissions "$dirpath" "directory"
        else
            echo -e "${RED}创建失败，请检查权限！${NC}"
        fi
    else
        echo -e "${YELLOW}已取消操作${NC}"
    fi
    wait_key
}

# 10. 创建文件
create_file() {
    read -p "输入要创建的文件路径及文件名: " filepath
    if [ -z "$filepath" ]; then
        echo -e "${RED}路径不能为空！${NC}"
        return
    fi
    
    if confirm_action "创建文件" "$filepath"; then
        if touch "$filepath"; then
            echo -e "${GREEN}文件创建成功！${NC}"
            recommend_permissions "$filepath" "file"
        else
            echo -e "${RED}创建失败，请检查权限！${NC}"
        fi
    else
        echo -e "${YELLOW}已取消操作${NC}"
    fi
    wait_key
}

# 11. 删除目录/文件
delete_target() {
    read -p "输入要删除的目录或文件的路径: " target
    if [ -z "$target" ]; then
        echo -e "${RED}路径不能为空！${NC}"
        return
    fi
    
    if [ ! -e "$target" ]; then
        echo -e "${RED}目标不存在！${NC}"
        return
    fi
    
    if confirm_action "删除" "$target"; then
        if [ -d "$target" ]; then
            rm -r "$target" && echo -e "${GREEN}目录删除成功！${NC}" || echo -e "${RED}删除失败！${NC}"
        else
            rm "$target" && echo -e "${GREEN}文件删除成功！${NC}" || echo -e "${RED}删除失败！${NC}"
        fi
    else
        echo -e "${YELLOW}已取消操作${NC}"
    fi
    wait_key
}

# 12. 编辑文件
edit_file() {
    read -p "输入要编辑的文件路径:（编辑模式：Vim：按 ESC → 输入 :wq → 回车  Nano：按 Ctrl+O 保存 → Ctrl+X 退出 ） " filepath
    if [ -z "$filepath" ]; then
        echo -e "${RED}路径不能为空！${NC}"
        return
    fi
    
    if [ ! -f "$filepath" ]; then
        echo -e "${RED}文件不存在或不是普通文件！${NC}"
        return
    fi
    
    if [ ! -w "$filepath" ]; then
        echo -e "${RED}无写权限，尝试获取权限...${NC}"
        if ! sudo chmod u+w "$filepath"; then
            echo -e "${RED}无法获取写权限！${NC}"
            return
        fi
    fi
    
    # 检测可用编辑器
    editor=${EDITOR:-nano}
    command -v $editor >/dev/null || editor="vi"
    
    $editor "$filepath"
    echo -e "${GREEN}编辑完成！${NC}"
    wait_key
}

# 13. 查找文件/目录
search_files() {
    read -p "输入查找路径（默认当前目录）: " searchpath
    read -p "输入查找名称（支持通配符）: " pattern
    
    searchpath=${searchpath:-.}
    
    if [ -z "$pattern" ]; then
        echo -e "${RED}搜索模式不能为空！${NC}"
        return
    fi
    
    echo -e "${BLUE}搜索结果：${NC}"
    find "$searchpath" -name "$pattern" -print | while read result; do
        if [ -d "$result" ]; then
            echo -e "${GREEN}[目录] ${result}${NC}"
        else
            echo -e "${YELLOW}[文件] ${result}${NC}"
        fi
    done
    
    wait_key
}

# 权限建议函数
recommend_permissions() {
    local target=$1
    local type=$2
    
    echo -e "\n${BLUE}权限建议：${NC}"
    case $type in
        "directory")
            echo -e "• 普通目录： ${GREEN}755 (drwxr-xr-x)${NC}"
            echo -e "• 敏感目录： ${GREEN}700 (drwx------)${NC}"
            echo -e "当前权限： $(stat -c "%a %A" "$target")"
            ;;
        "file")
            echo -e "• 配置文件： ${GREEN}644 (-rw-r--r--)${NC}"
            echo -e "• 可执行文件： ${GREEN}755 (-rwxr-xr-x)${NC}"
            echo -e "• 敏感文件： ${GREEN}600 (-rw-------)${NC}"
            echo -e "当前权限： $(stat -c "%a %A" "$target")"
            ;;
    esac
}

main

