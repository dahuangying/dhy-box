#!/bin/bash
# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检查是否为 root 权限
if [ "$(id -u)" != "0" ]; then
    echo -e "\n============================================="
    echo -e "           请使用 ROOT 权限运行此工具！"
    echo -e "          例如：sudo bash 你的脚本.sh"
    echo -e "=============================================\n"
    exit 1
fi

# 暂停函数
pause() {
    echo -e "\n${GREEN}操作完成，按任意键返回菜单...${NC}"
    read -n 1 -s -r
    echo
}

wait_key() {
    pause
}

# 系统工具功能菜单
show_base_menu() {
    clear
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}  大黄鹰-Linux服务器运维工具箱菜单-系统工具  ${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${YELLOW}请选择需要执行的操作：${NC}"
    echo ""
    echo "1. 开启系统自带 BBR 加速"
    echo "2. 查询当前 TCP 拥塞控制算法"
    echo "3. 启用ROOT密码登录模式"
    echo "4. 禁用ROOT密码登录"
    echo "5. 修改ROOT密码"
    echo "6. SWAP虚拟内存管理"
    echo "7. Linux普通用户管理"	
    echo "0. 退出"
    echo -e "${GREEN}=============================================${NC}"
    read -p "请输入选项编号: " choice
    case $choice in
        1) bbr_acceleration ;;
        2) query_tcp_congestion ;;
        3) enable_root_login ;;
        4) disable_root_login ;;
        5) change_root_password ;;
        6) swap_sub_menu ;;
        7) user_sub_menu ;;		
        0) exit 0 ;;
        *) 
            echo -e "${RED}无效输入，请重试！${NC}"
            sleep 1
            ;;
    esac
}

# 1. 开启BBR
bbr_acceleration() {
    clear
    echo -e "${GREEN}正在开启系统 BBR 加速...${NC}"
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    lsmod | grep bbr
    pause
}

# 2. 查询TCP算法
query_tcp_congestion() {
    clear
    echo -e "${GREEN}当前 TCP 拥塞控制算法：${NC}"
    sysctl net.ipv4.tcp_congestion_control
    pause
}

# 3. 启用ROOT密码登录模式
enable_root_login() {
    clear
    echo -e "${GREEN}=== 启用ROOT密码登录模式 ===${NC}"

    # 设置 root 密码
    if ! passwd root; then
        echo -e "${RED}密码设置失败${NC}" 
        wait_key
        return 1
    fi

    # 修改主配置文件
    sed -i '/^\s*#\?\s*PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
    sed -i '/^\s*#\?\s*PasswordAuthentication/c\PasswordAuthentication yes' /etc/ssh/sshd_config
    sed -i '/^\s*#\?\s*PubkeyAuthentication/c\PubkeyAuthentication yes' /etc/ssh/sshd_config

    # 修复 sshd_config.d/*.conf 中的 PasswordAuthentication no
    # 在脚本开头定义（设为true时显示，false时静默）
    VERBOSE=false
    if [ -d /etc/ssh/sshd_config.d ]; then
        for file in /etc/ssh/sshd_config.d/*.conf; do
            [ -f "$file" ] || continue
            if grep -qE "^\s*PasswordAuthentication\s+no" "$file"; then
                $VERBOSE && echo -e "${YELLOW}检测到 $file 中禁用了密码登录，正在修改为允许...${NC}"
                sed -i 's/^\s*PasswordAuthentication\s\+no/PasswordAuthentication yes/' "$file" $($VERBOSE || echo ">/dev/null")
            fi
        done
    fi
    
    # 重启 SSH 服务
    echo -e "${YELLOW}正在重启SSH服务...${NC}"
    if systemctl restart ssh 2>/dev/null || \
       systemctl restart sshd 2>/dev/null || \
       service ssh restart 2>/dev/null || \
       service sshd restart 2>/dev/null; then
        echo -e "${GREEN}服务重启成功${NC}"
    else
        echo -e "${RED}服务重启失败，请手动执行以下命令：${NC}"
        echo "Ubuntu/Debian: systemctl restart ssh"
        echo "CentOS/RHEL:   systemctl restart sshd"
        return 1
    fi

    # 输出当前有效配置
    echo -e "${GREEN}✔ 已启用ROOT登录${NC}"
    echo -e "当前配置文件中内容："
    grep -E "PermitRootLogin|PasswordAuthentication|PubkeyAuthentication" /etc/ssh/sshd_config
    echo -e "\n当前 sshd 实际加载配置："
    sshd -T 2>/dev/null | grep -E "permitrootlogin|passwordauthentication|pubkeyauthentication" || \
        echo -e "${YELLOW}警告：无法获取运行时配置，请确保sshd -T命令可用${NC}"
    
    wait_key
}

# 4. 禁用ROOT密码登录（增加确认）
disable_root_login() {
    echo -e "\n${RED}=== 禁用ROOT密码登录 ===${NC}"
    echo -e "${YELLOW}警告：禁用后将无法直接使用ROOT密码登录系统！${NC}"
    
    read -p "确定要禁用吗？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}已取消操作${NC}"
        wait_key
        return
    fi

    sed -i 's/^#*PermitRootLogin.*/#PermitRootLogin no/g' /etc/ssh/sshd_config
    
    # 直接在这里重启SSH，不依赖任何外部函数
    echo -e "${YELLOW}正在重启SSH服务...${NC}"
    if systemctl restart ssh 2>/dev/null || \
       systemctl restart sshd 2>/dev/null || \
       service ssh restart 2>/dev/null || \
       service sshd restart 2>/dev/null; then
        echo -e "${GREEN}ROOT密码登录已禁用！${NC}"
    else
        echo -e "${RED}SSH服务重启失败！${NC}"
    fi
    wait_key
}

# 5. 修改ROOT密码
change_root_password() {
    echo -e "\n${YELLOW}=== 修改ROOT密码 ===${NC}"
    echo -e "${BLUE}（直接回车取消操作）${NC}"
    passwd root
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}密码修改成功！${NC}"
    else
        echo -e "${YELLOW}已取消密码修改${NC}"
    fi
    wait_key
}

# 6.swap虚拟内存管理
swap_sub_menu() {
    while true; do
        clear
        echo "======== 虚拟内存管理子菜单 ========"
        echo "1. 查询虚拟内存状态"
        echo "2. 创建自定义虚拟内存"
        echo "3. 卸载并清空虚拟内存"
        echo "0. 返回上级主菜单"
        echo -n "请输入选项："
        read opt
        case $opt in
            1) swap_query ;;
            2) swap_create ;;
            3) swap_remove ;;
            0) break ;;
            *) echo "无效选项"; sleep 1 ;;
        esac
    done
}
# 查询虚拟内存状态
swap_query() {
    clear
    echo "=== 当前虚拟内存状态 ==="
    swapon --show
    echo -e "\n系统内存信息："
    free -h
    echo -e "\n当前 swappiness 阈值：$(sysctl -n vm.swappiness)"
    wait_key
}
# 创建虚拟内存
swap_create() {
    clear
    echo "=== 创建虚拟内存 ==="
    echo "示例格式：1G  2G  4G  8G"
    echo -n "请输入虚拟内存大小："
    read swap_size

    if [ -z "$swap_size" ]; then
        echo "未输入大小，已取消"
        wait_key
        return
    fi

    # 就只加这一行，自动补G，其它全不动
    swap_size=${swap_size}G

    read -p "确认创建 $swap_size 虚拟内存？(y/n)：" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消"
        wait_key
        return
    fi

# ↓↓↓↓↓ 你要的 6 步命令 100% 原样执行 ↓↓↓↓↓
fallocate -l $swap_size /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 'vm.swappiness=10' >> /etc/sysctl.conf
sysctl -p
# ↑↑↑↑↑ 你要的 6 步命令 100% 原样执行 ↑↑↑↑↑

    echo -e "\n创建完成！"
    swapon --show
    wait_key
}
# 删除虚拟内存
swap_remove() {
    clear
    echo "=== 彻底卸载虚拟内存 所有配置还原 ==="
    read -p "确定删除所有swap文件及配置？(y/n)：" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消"
        wait_key
        return
    fi

    swapoff /swapfile 2>/dev/null
    rm -f /swapfile
    sed -i '/\/swapfile/d' /etc/fstab
    sed -i '/vm.swappiness=10/d' /etc/sysctl.conf
    sysctl -p

    echo "全部清理完成，恢复系统默认"
    wait_key
}

# 7. Linux 通用普通用户管理
user_sub_menu() {
    while true; do
        clear
        echo "======== Linux 通用普通用户管理子菜单 ========"
        echo "1. 查询系统所有普通用户"
        echo "2. 创建普通用户"
        echo "3. 删除普通用户(连带家目录)"
        echo "0. 返回上级主菜单"
        echo -n "请输入选项："
        read opt
        case $opt in
            1) user_query ;;
            2) user_create ;;
            3) user_delete ;;
            0) break ;;
            *) echo "无效选项"; sleep 1 ;;
        esac
    done
}

# 查询普通用户（通用所有Linux）
user_query() {
    clear
    echo "=== 当前系统普通用户列表 ==="
    awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd
    wait_key
}

# 创建普通用户（通用所有Linux）
user_create() {
    clear
    echo "=== 创建 Linux 普通用户 ==="
    echo "提示：直接回车使用默认用户名：user01"
    echo -n "请输入用户名："
    read username

    if [ -z "$username" ]; then
        username="user01"
    fi

    if id -u "$username" >/dev/null 2>&1; then
        echo -e "\n用户 $username 已存在！"
        wait_key
        return
    fi

    read -p "确认创建用户 $username ? (y/n)：" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消"
        wait_key
        return
    fi

    # 通用创建命令，全系统兼容
    useradd -m -s /bin/bash "$username"

    # ========== 只改这里：干净 y/n，无多余提示 ==========
    read -p "是否设置用户密码？(y/n)：" set_pwd
    if [[ "$set_pwd" == "y" || "$set_pwd" == "Y" ]]; then
        passwd "$username"
    else
        echo -e "\n已跳过密码设置"
    fi

    echo -e "\n用户创建完成！"
    wait_key
}

# 删除普通用户（通用所有Linux + 删家目录）
user_delete() {
    clear
    echo "=== 删除 Linux 普通用户 ==="
    echo "当前普通用户："
    awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd
    echo -n "请输入要删除的用户名："
    read username

    if [ -z "$username" ]; then
        echo "未输入用户名，已取消"
        wait_key
        return
    fi

    if ! id -u "$username" >/dev/null 2>&1; then
        echo -e "\n用户不存在！"
        wait_key
        return
    fi

    read -p "警告：删除用户及家目录，确认继续？(y/n)：" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消"
        wait_key
        return
    fi

    userdel -r "$username"
    echo -e "\n用户 $username 已彻底删除！"
    wait_key
}

# ==============================
# 程序入口
# ==============================
while true; do
    show_base_menu
done
