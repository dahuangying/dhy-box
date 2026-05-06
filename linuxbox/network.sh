#!/bin/bash

# 设置颜色
GREEN='\033[0;32m'
NC='\033[0m' # 无色
RED='\033[0;31m'

# 显示暂停，按任意键继续
pause() {
    echo -e "${GREEN}操作完成，按任意键继续...${NC}"
    read -n 1 -s -r  # 等待用户按下任意键
    echo
}

# 1. 哪吒监控面板
install_nezajiankong_cron() {
    echo -e "${GREEN}安装哪吒监控面板...${NC}"
    curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
    pause
}

# 2. dpanel可视化管理面板
install_dpanel_panel() {
    echo -e "${GREEN}安装 dpanel可视化管理面板 ${NC}"
    curl -sSL https://dpanel.cc/quick.sh -o quick.sh && sudo bash quick.sh
    pause
}

# 3. BBRplus 加速
bbr_plus_acceleration() {
    echo -e "${GREEN}安装BBRplus加速...${NC}"
    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    pause
}

# 4. X-UI面板
install_xui_panel() {
    echo -e "${GREEN}安装X-UI面板...${NC}"
    bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh)
    pause
}

# 5. 3X-UI面板
install_3xui_panel() {
    echo -e "${GREEN}安装3X-UI面板...${NC}"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
    pause
}

# 6. 极光面板
install_aurora_panel() {
    echo -e "${GREEN}安装极光面板...${NC}"
    bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
    pause
}

# 7. 1Panel管理面板
install_1pane_panel() {
    echo -e "${GREEN}安装1Panel管理面板...${NC}"

    # 配置项
    PANEL_INSTALL_DIR="/opt/1panel"
    PANEL_SERVICE_FILE="/etc/systemd/system/1panel.service"

    # 函数：显示菜单
    show_1Panel_menu() {
        clear
        
        # 检查是否已安装 1Panel
        if [ -d "$PANEL_INSTALL_DIR" ] || [ -f "$PANEL_SERVICE_FILE" ]; then
            INSTALL_STATUS="已安装"
        else
            INSTALL_STATUS="未安装"
        fi

        echo -e "${GREEN}1Panel 安装状态: $INSTALL_STATUS${NC}"
        echo -e "${GREEN}安装目录: $PANEL_INSTALL_DIR${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}大黄鹰-Linux服务器运维工具箱菜单-1Panel${NC}"
        echo -e "欢迎使用本脚本，请根据菜单选择操作："
        echo -e "${GREEN}========================================${NC}"
        
        echo "1. 安装 1Panel"
        echo "2. 查看面板信息"
        echo "3. 修改密码"
        echo "4. 卸载 1Panel"
        echo "0. 返回上级菜单"
        read -p "请输入选项: " option
        case $option in
            1) install_panel ;;
            2) view_panel_info ;;
            3) update_password ;;
            4) uninstall_panel ;;
            0) return ;;          # 修复1：改成return
            *) echo "无效的选项，请重新选择！" && sleep 2 && show_1Panel_menu ;;  # 修复2：改名
        esac
    }

    # 函数：安装 1Panel
    install_panel() {
        echo "开始安装 1Panel..."
        curl -sSL https://resource.1panel.pro/quick_start.sh -o quick_start.sh && bash quick_start.sh
        echo "1Panel 安装完成！"
        echo "您可以通过 1pctl user-info 查看面板信息"
        pause
        show_1Panel_menu
    }

    # 函数：查看面板信息
    view_panel_info() {
        echo "正在获取面板信息..."
        1pctl user-info
        pause
        show_1Panel_menu
    }

    # 函数：修改密码
    update_password() {
        echo "正在修改密码..."
        1pctl update password
        pause
        show_1Panel_menu
    }

    # 函数：卸载 1Panel
    uninstall_panel() {
        read -p "您确定要卸载 1Panel 并删除所有相关文件吗？[y/n]: " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo "正在卸载 1Panel..."
            sudo systemctl stop 1panel
            sudo systemctl disable 1panel
            sudo find / -name "1panel*" -exec sudo rm -rf {} \;
            sudo rm -f /root/1panel-v1.10.29-lts-linux-amd64/1panel.service
            sudo rm -f /etc/systemd/system/1panel.service
            [ -d "$PANEL_INSTALL_DIR" ] && sudo rm -rf "$PANEL_INSTALL_DIR"
            sudo rm -f /var/log/1panel.log
            echo "1Panel 卸载完成！"
        else
            echo "取消卸载。"
        fi
        pause
        show_1Panel_menu
    }

    # 启动1Panel菜单
    show_1Panel_menu
}

# 8. NginxProxyManager 可视化面板
install_nginx_proxy_manager_panel() {
    echo -e "${GREEN}安装 Nginx Proxy Manager 可视化面板...${NC}"

    # 判断 Nginx Proxy Manager 是否已安装
    check_nginx_installed() {
        if [ -d "/opt/nginx-proxy-manager" ]; then
            return 0  # 已安装
        else
            return 1  # 未安装
        fi
    }

    # 用户确认函数
    confirm_action() {
        echo -e "${RED}你确定要卸载 Nginx Proxy Manager 吗？（y/n）${NC}"
        read confirmation
        if [[ $confirmation != "y" && $confirmation != "Y" ]]; then
            echo -e "${GREEN}操作已取消。${NC}"
            return 1
        fi
        return 0
    }

    # 停止并删除容器
    remove_container() {
        container_id=$(docker ps -a -q --filter "name=nginx-proxy-manager")
        if [ -n "$container_id" ]; then
            echo -e "${GREEN}正在停止并删除容器...${NC}"
            docker stop $container_id
            docker rm $container_id
        else
            echo -e "${GREEN}未找到 Nginx Proxy Manager 容器，无需删除。${NC}"
        fi
    }

    # 删除镜像
    remove_image() {
        image_id=$(docker images -q "jc21/nginx-proxy-manager")
        if [ -n "$image_id" ]; then
            echo -e "${GREEN}正在删除镜像...${NC}"
            docker rmi -f $image_id
        else
            echo -e "${GREEN}未找到 Nginx Proxy Manager 镜像，无需删除。${NC}"
        fi
    }

    # 删除 Docker Compose 配置和数据
    remove_files() {
        echo -e "${GREEN}正在删除 Docker Compose 配置和数据文件...${NC}"
        rm -rf /opt/nginx-proxy-manager
        echo -e "${GREEN}配置和数据文件已删除。${NC}"
    }

    # 清理防火墙规则
    remove_firewall_rules() {
        echo -e "${GREEN}正在移除防火墙规则...${NC}"
        ufw status | grep -E '80|443|81' && ufw delete allow 80 && ufw delete allow 443 && ufw delete allow 81
        ufw reload
        echo -e "${GREEN}防火墙规则已移除。${NC}"
    }

    # 安装 Nginx Proxy Manager
    install_nginx_proxy_manager() {
        echo "正在安装 Nginx Proxy Manager..."

        # 设置防火墙
        read -p "请输入应用对外服务端口，回车默认使用81端口: " port
        port=${port:-81}
        ufw allow $port
        ufw reload

        # 安装 Docker 和 Docker Compose
        apt update && apt upgrade -y
        apt install -y curl ufw sudo
        curl -fsSL https://get.docker.com | bash
        systemctl start docker
        systemctl enable docker

        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        # 创建目录并配置 Docker Compose
        mkdir -p /opt/nginx-proxy-manager/data
        mkdir -p /opt/nginx-proxy-manager/letsencrypt
        cat > /opt/nginx-proxy-manager/docker-compose.yml <<EOL
version: '3'

services:
  app:
    image: 'docker.io/jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - "80:80"
      - "$port:$port"
      - "443:443"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOL

        # 启动服务
        cd /opt/nginx-proxy-manager
        docker-compose up -d

        # 输出安装完成的提示
        echo -e "${GREEN}安装完成，请访问地址：http://【你的服务器IP】:${port}${NC}"
        echo -e "${GREEN}初始用户名: admin@example.com${NC}"
        echo -e "${GREEN}初始密码: changeme${NC}"
        sleep 2
        pause
    }

    # 更新 Nginx Proxy Manager
    update_nginx_proxy_manager() {
        echo "正在更新 Nginx Proxy Manager..."
        if check_nginx_installed; then
            cd /opt/nginx-proxy-manager
            docker-compose pull
            docker-compose up -d
            echo "更新完成！"
        else
            echo -e "${RED}Nginx Proxy Manager 未安装，无法更新！${NC}"
        fi
        sleep 2
        pause
    }

    # 卸载 Nginx Proxy Manager
    uninstall_nginx_proxy_manager() {
        confirm_action
        if [ $? -eq 0 ]; then
            remove_container
            remove_image
            remove_files
            remove_firewall_rules
            echo -e "${GREEN}Nginx Proxy Manager 已成功卸载。${NC}"
        else
            echo -e "${GREEN}卸载操作已取消。${NC}"
        fi
        pause
    }

    # Nginx子菜单
    show_nginx_menu() {
        while true; do
            clear
            echo -e "${GREEN}大黄鹰-Linux服务器运维工具箱菜单-Nginx${NC}"
            echo -e "${GREEN}==================================${NC}"
            if check_nginx_installed; then
                echo "Nginx Proxy Manager 状态: 已安装"
            else
                echo "Nginx Proxy Manager 状态: 未安装"
            fi
            echo -e "${GREEN}==================================${NC}"
            echo "1. 安装"
            echo "2. 更新"
            echo "3. 卸载"
            echo "0. 返回上级菜单"
            echo "=================================="
            read -p "请输入选项: " option
            case $option in
                1) install_nginx_proxy_manager ;;
                2) update_nginx_proxy_manager ;;
                3) uninstall_nginx_proxy_manager ;;
                0) return ;;  # 返回主菜单
                *) echo "无效选项，请重新选择！" ; sleep 2 ;;
            esac
        done
    }

    # 启动Nginx子菜单
    show_nginx_menu
}

# 9. AList网盘
install_alist_panel() {
    echo -e "${GREEN}安装 AList 网盘...${NC}"
    curl -fsSL "https://alist.nn.ci/v3.sh" -o v3.sh && bash v3.sh
    pause
}

# 10. 甲骨文保活脚本
install_oracle_keep_alive() {
    echo -e "${GREEN}安装甲骨文保活脚本...${NC}"
    curl -L https://gitlab.com/spiritysdx/Oracle-server-keep-alive-script/-/raw/main/oalive.sh -o oalive.sh && chmod +x oalive.sh && bash oalive.sh
    pause
}


# 主菜单
show_menu() {
    echo -e "${GREEN}大黄鹰-Linux服务器运维工具箱菜单-应用市场${NC}"
    echo -e "欢迎使用本脚本，请根据菜单选择操作："
    echo -e "${GREEN}==================================${NC}"
    echo "1. 安装 哪吒监控面板"
    echo "2. 安装 dpanel可视化管理面板"	
    echo "3. BBRplus 加速"
    echo "4. 安装 X-UI 面板"
    echo "5. 安装 3X-UI 面板"
    echo "6. 安装 极光面板"
    echo "7. 安装 1Pane 管理面板"
    echo "8. 安装 Nginx Proxy Manager 可视化面板"
    echo "9. 安装 AList 网盘"
    echo "10. 安装 甲骨文保活脚本"
    echo "0. 退出"
    read -p "请输入选项编号: " choice
    case $choice in
        1)
            install_nezajiankong_cron
            ;;
        2)
            install_dpanel_panel
            ;;	
        3)
            bbr_plus_acceleration
            ;;
        4)
            install_xui_panel
            ;;
        5)
            install_3xui_panel
            ;;
        6)
            install_aurora_panel
            ;;
        7)
            install_1pane_panel
            ;;
        8)
            install_nginx_proxy_manager_panel
            ;;
        9)
            install_alist_panel
            ;;
        10)
            install_oracle_keep_alive
            ;;
        0)
            echo "感谢使用大黄鹰-运维工具箱！"
            exit 0
            ;;
        *)
            echo "无效输入，请重试。"
            ;;
    esac
}

# 主程序入口
while true; do
    show_menu
done

