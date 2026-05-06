#!/bin/bash

# 设置颜色变量（新增黄色、青色、红色）
GREEN="\033[0;32m"  # 绿色
YELLOW="\033[1;33m" # 黄色
CYAN="\033[0;36m"   # 青色
RED="\033[0;31m"    # 红色
NC="\033[0m"        # 重置颜色

# ========== 优化10：退出陷阱清理 ==========
cleanup() {
    echo -e "\n${YELLOW}脚本执行结束，清理临时文件...${NC}"
    # 清理临时容器（匹配 _tmp_ 后缀）
    docker rm -f $(docker ps -a --filter "name=_tmp_" -q) 2>/dev/null || true
}
trap cleanup EXIT

# ========== 优化2：confirm_action 移到前面（解决函数未定义问题） ==========
# 安全确认函数
confirm_action() {
    local prompt="$1"
    read -p "$(echo -e "${YELLOW}${prompt} (y/N): ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] && return 0 || return 1
}

# ========== Docker 权限检查（进入 Docker 菜单时自动授权） ==========
check_docker_permission() {
    # 如果不是 root，自动用 sudo 重新运行
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}正在使用 sudo 权限进入 Docker 管理菜单...${NC}"
        exec sudo bash modules/docker.sh
        exit 0
    fi
}

# ========== 优化9：Docker 版本兼容性检查 ==========
check_docker_version() {
    local min_version="20.10.0"
    local current_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    if [ -n "$current_version" ]; then
        # 拆分版本号进行比较
        local min_arr=(${min_version//./ })
        local curr_arr=(${current_version//./ })
        for i in 0 1 2; do
            if [[ ${curr_arr[$i]:-0} -lt ${min_arr[$i]:-0} ]]; then
                echo -e "${YELLOW}警告：当前 Docker 版本 $current_version 可能过旧，建议升级到 $min_version 以上${NC}"
                break
            elif [[ ${curr_arr[$i]:-0} -gt ${min_arr[$i]:-0} ]]; then
                break
            fi
        done
    fi
}

# 显示主菜单
show_menu() {
    clear
    # ========== 优化10：null 安全的方式获取资源数量 ==========
    # 获取当前环境数据（增加错误重定向）
    if ! command -v docker &> /dev/null; then
        containers=0
        images=0
        networks=0
        volumes=0
    else
        containers=$(docker ps -a -q 2>/dev/null | wc -l | awk '{print $1}')
        images=$(docker images -q 2>/dev/null | wc -l | awk '{print $1}')
        networks=$(docker network ls -q 2>/dev/null | wc -l | awk '{print $1}')
        volumes=$(docker volume ls -q 2>/dev/null | wc -l | awk '{print $1}')
        # 检查 Docker 版本
        check_docker_version
    fi

    # 显示环境状态
    echo -e "${GREEN}环境状态： 容器: $containers  镜像: $images  网络: $networks  卷: $volumes ${NC}"
     # 显示 Docker 安装状态
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker 已安装${NC}"
    else
        echo -e "${RED}Docker 未安装${NC}"
    fi
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}大黄鹰-Linux服务器运维工具箱菜单-Docker 管理脚本${NC}"
    echo -e "欢迎使用本脚本，请根据菜单选择操作："
    echo -e "${GREEN}====================================================${NC}"
    echo "1. 查看 Docker 容器、镜像、卷和网络状态"
    echo "2. 安装/更新 Docker 环境"
	echo "3. 更新 Docker 容器" 
	echo "4. 清理 Docker 容器"
    echo "5. Docker 容器管理"
    echo "6. Docker 镜像管理"
    echo "7. Docker 网络管理"
    echo "8. Docker 卷管理"
    echo "9. 卸载 Docker 环境"
    echo "0. 退出"
    read -p "请输入选项: " option
    case $option in
        1) show_docker_status ;;
        2) install_update_docker ;;
	3) update_menu ;;
	4) docker_cleanup ;;
        5) docker_container_management ;;
        6) docker_image_management ;;
        7) docker_network_management ;;
        8) docker_volume_management ;;
	9) uninstall_docker_environment ;;
		
        0) exit 0 ;;
        *) echo "无效的选项，请重新选择！" && sleep 2 && show_menu ;;
    esac
}

# 1. 查看 Docker 容器、镜像、卷和网络状态
show_docker_status() {
    # ========== 优化1：重新定义变量（解决作用域问题） ==========
    # 在函数内重新获取数量
    local containers=$(docker ps -a -q 2>/dev/null | wc -l | awk '{print $1}')
    local images=$(docker images -q 2>/dev/null | wc -l | awk '{print $1}')
    local networks=$(docker network ls -q 2>/dev/null | wc -l | awk '{print $1}')
    local volumes=$(docker volume ls -q 2>/dev/null | wc -l | awk '{print $1}')

    echo -e "${GREEN}==============================${NC}"
    echo -e "${GREEN}Docker版本${NC}"
    docker --version || true
    # ========== 优化6：Docker Compose 插件检查 ==========
    echo -e "\n${GREEN}Docker Compose版本${NC}"
    if command -v docker-compose &> /dev/null; then
        docker-compose --version || true
    elif docker compose version &> /dev/null; then
        docker compose version || true
    else
        echo -e "${YELLOW}Docker Compose 未安装${NC}"
    fi

    echo -e "\n${GREEN}==============================${NC}"
    echo -e "${GREEN}Docker容器: $containers${NC}"
    docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}" || true

    echo -e "\n${GREEN}==============================${NC}"
    echo -e "${GREEN}Docker镜像: $images${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" || true

    echo -e "\n${GREEN}==============================${NC}"
    echo -e "${GREEN}Docker网络: $networks${NC}"
    docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" || true

    echo -e "\n${GREEN}==============================${NC}"
    echo -e "${GREEN}Docker卷: $volumes${NC}"
    docker volume ls --format "table {{.Driver}}\t{{.Name}}" || true

    pause
    show_menu
}

# 2. 安装或更新 Docker 环境（优化：动态适配系统版本，带更新检测）
install_update_docker() {
    # 检查是否为 root 权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：安装/更新 Docker 需要 root 权限，请使用 sudo 运行脚本${NC}"
        pause
        show_menu
        return 1
    fi

    echo -e "${CYAN}正在检测系统环境，准备安装/更新 Docker...${NC}"

    # ========== 步骤1：检测系统信息 ==========
    local DISTRO=""
    local DISTRO_VERSION=""
    local ARCH=$(uname -m)
    local kernel_version=$(uname -r | cut -d'.' -f1-2 | sed 's/-//g')
    local min_kernel="4.19"  # 官方版最低推荐内核版本

    # 检测发行版
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        # 提取发行版主版本号
        if [[ "$DISTRO" == "ubuntu" ]]; then
            DISTRO_VERSION=$(lsb_release -rs 2>/dev/null | cut -d'.' -f1)
        elif [[ "$DISTRO" == "debian" ]]; then
            DISTRO_VERSION=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release | cut -d'.' -f1)
        elif [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
            DISTRO_VERSION=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release | cut -d'.' -f1)
        else
            echo -e "${RED}不支持的操作系统：$DISTRO${NC}"
            pause
            show_menu
            return 1
        fi
    else
        echo -e "${RED}无法检测系统发行版${NC}"
        pause
        show_menu
        return 1
    fi

    # 适配架构
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armhf" ;;
        *) echo -e "${YELLOW}警告：不识别的架构 $ARCH，使用默认 amd64${NC}"; ARCH="amd64" ;;
    esac

    # ========== 新增：检测当前 Docker 版本并判断是否需要更新 ==========
    local current_docker_version=""
    local current_compose_version=""
    local need_update=false
    local latest_docker_version=""
    local latest_compose_version=""
    
    # 获取最新版本（通过 GitHub API）
    get_latest_versions() {
        # 获取最新 Docker 版本（从 GitHub API）
        latest_docker_version=$(curl -s https://api.github.com/repos/moby/moby/releases/latest 2>/dev/null | grep -oP '"tag_name": "\K(.*?)(?=")')
        if [[ -z "$latest_docker_version" ]]; then
            latest_docker_version="29.2.1"
        else
            # 移除可能的 'v' 或 'docker-' 前缀
            latest_docker_version=$(echo "$latest_docker_version" | sed -E 's/^(v|docker-v)//g')
        fi
        
        # 获取最新 Compose 版本
        latest_compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep -oP '"tag_name": "\K(.*?)(?=")')
        if [[ -z "$latest_compose_version" ]]; then
            latest_compose_version="5.0.2"
        else
            # 移除可能的 'v' 前缀
            latest_compose_version=$(echo "$latest_compose_version" | sed 's/^v//g')
        fi
    }
    
    if command -v docker &>/dev/null; then
        current_docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
        current_compose_version=$(docker compose version --short 2>/dev/null 2>/dev/null || echo "未知")
        
        # 获取最新版本
        get_latest_versions
        
        # 判断是否需要更新
        if [[ "$current_docker_version" != "$latest_docker_version" ]] || [[ "$current_compose_version" != "$latest_compose_version" ]]; then
            echo -e "${YELLOW}当前版本: Docker ${current_docker_version} / Compose ${current_compose_version}${NC}"
            echo -e "${GREEN}最新版本: Docker ${latest_docker_version} / Compose ${latest_compose_version}${NC}"
            if confirm_action "检测到新版本，是否更新？"; then
                need_update=true
            else
                echo -e "${YELLOW}已取消更新${NC}"
                pause
                show_menu
                return 0
            fi
        else
            echo -e "${GREEN}当前 Docker ${current_docker_version} / Compose ${current_compose_version} 已是最新版${NC}"
            if ! confirm_action "是否重新安装？"; then
                pause
                show_menu
                return 0
            fi
            need_update=true
        fi
    else
        echo -e "${YELLOW}未检测到 Docker，将执行全新安装${NC}"
        need_update=true
    fi

    # 修复：内核版本比较（添加默认值防止空值错误）
    local kernel_major=$(echo $kernel_version | cut -d'.' -f1)
    local kernel_minor=$(echo $kernel_version | cut -d'.' -f2)
    local min_major=$(echo $min_kernel | cut -d'.' -f1)
    local min_minor=$(echo $min_kernel | cut -d'.' -f2)

    # 给变量设置默认值 0
    kernel_major=${kernel_major:-0}
    kernel_minor=${kernel_minor:-0}
    min_major=${min_major:-0}
    min_minor=${min_minor:-0}

    # ========== 步骤2：添加 Docker GPG 密钥（通用函数，全自动覆盖） ==========
    add_docker_gpg_key() {
        echo -e "${YELLOW}▶ 添加 Docker 官方 GPG 密钥...${NC}"
        local gpg_key_url=""
        local gpg_keyring_path="/etc/apt/trusted.gpg.d/docker.gpg"
        local rpm_gpg_path="/etc/pki/rpm-gpg/RPM-GPG-KEY-docker"

        if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
            gpg_key_url="https://download.docker.com/linux/$DISTRO/gpg"
            # 安装必要工具
            apt-get install -y ca-certificates curl gnupg -y 2>/dev/null || true
            # 创建密钥存储目录
            mkdir -p /etc/apt/trusted.gpg.d 2>/dev/null || true
            
            # ========== 全自动覆盖逻辑（修复版） ==========
            if [[ -f "$gpg_keyring_path" ]]; then
                echo -e "${YELLOW}▶ 文件 ${RED}$gpg_keyring_path${YELLOW} 已存在，自动覆盖...${NC}"
                # 先删除旧文件
                rm -f "$gpg_keyring_path" 2>/dev/null || true
            fi
            # 使用重定向而不是 -o 参数，避免提示
            curl -fsSL "$gpg_key_url" | gpg --dearmor > "$gpg_keyring_path" 2>/dev/null || true
            # ========== 全自动覆盖逻辑结束 ==========

            chmod 644 "$gpg_keyring_path" 2>/dev/null || true
        elif [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
            gpg_key_url="https://download.docker.com/linux/centos/gpg"
            
            # ========== 全自动覆盖逻辑 ==========
            if [[ -f "$rpm_gpg_path" ]]; then
                echo -e "${YELLOW}▶ 文件 ${RED}$rpm_gpg_path${YELLOW} 已存在，自动覆盖...${NC}"
            fi
            curl -fsSL "$gpg_key_url" > "$rpm_gpg_path" 2>/dev/null || true
            rpm --import "$rpm_gpg_path" 2>/dev/null || true
            # ========== 全自动覆盖逻辑结束 ==========
        fi
        echo -e "${GREEN}✅ Docker 官方 GPG 密钥添加完成${NC}"
    }

    # ========== 新增：下载 Docker Compose 的函数（多源支持） ==========
    download_docker_compose() {
        local compose_version="1.29.2"
        local compose_dest="/usr/local/bin/docker-compose"
        local os_type=$(uname -s)
        local arch_type=$(uname -m)
        
        echo -e "${YELLOW}▶ 下载 Docker Compose v${compose_version}...${NC}"
        
        # 定义下载源列表（优先使用 GitHub，失败时使用阿里云镜像）
        local sources=(
            "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-${os_type}-${arch_type}"
            "https://mirrors.aliyun.com/docker-toolbox/linux/compose/${compose_version}/docker-compose-${os_type}-${arch_type}"
        )
        
        local download_success=false
        local source_index=1
        
        for source in "${sources[@]}"; do
            echo -e "${CYAN}  尝试源 $source_index: ${source}${NC}"
            
            if curl -L --connect-timeout 10 --max-time 60 -f "$source" -o "$compose_dest" 2>/dev/null; then
                chmod +x "$compose_dest"
                if [[ -x "$compose_dest" ]] && $compose_dest --version &>/dev/null; then
                    echo -e "${GREEN}  ✅ 从源 $source_index 下载成功${NC}"
                    download_success=true
                    break
                else
                    echo -e "${YELLOW}  ⚠ 下载文件可能损坏，尝试下一个源${NC}"
                    rm -f "$compose_dest" 2>/dev/null || true
                fi
            else
                echo -e "${YELLOW}  ⚠ 源 $source_index 下载失败${NC}"
            fi
            source_index=$((source_index + 1))
        done
        
        if [ "$download_success" = false ]; then
            echo -e "${RED}  ❌ 所有源均下载失败，请手动安装 Docker Compose${NC}"
            return 1
        fi
        
        return 0
    }

    # ========== 步骤3：智能选择安装版本 ==========
    install_docker_smart() {
        # 判断是否满足官方版安装条件
        local use_official=1
        
        # 修复：内核版本比较（使用 awk 替代 sort -V，因为 sort -V 在某些系统不可用）
        local kernel_major=$(echo $kernel_version | cut -d'.' -f1)
        local kernel_minor=$(echo $kernel_version | cut -d'.' -f2)
        local min_major=$(echo $min_kernel | cut -d'.' -f1)
        local min_minor=$(echo $min_kernel | cut -d'.' -f2)
        
        # 内核版本过低 → 用系统版
        if [ "$kernel_major" -lt "$min_major" ] || { [ "$kernel_major" -eq "$min_major" ] && [ "$kernel_minor" -lt "$min_minor" ]; }; then
            use_official=0
        # Ubuntu < 20.04 / CentOS < 8 / Debian < 10 → 用系统版
        elif [[ "$DISTRO" == "ubuntu" && "$DISTRO_VERSION" -lt 20 ]]; then
            use_official=0
        elif [[ "$DISTRO" == "centos" && "$DISTRO_VERSION" -lt 8 ]]; then
            use_official=0
        elif [[ "$DISTRO" == "debian" && "$DISTRO_VERSION" -lt 10 ]]; then
            use_official=0
        fi

        # 方案1：安装官方版（docker-ce）
        if [[ $use_official -eq 1 ]]; then
            echo -e "${CYAN}▶ 系统环境适配，安装 Docker 官方最新版${NC}"
            echo -e "${YELLOW}  - 内核版本：$kernel_version (≥ $min_kernel)${NC}"
            echo -e "${YELLOW}  - 系统版本：$DISTRO $DISTRO_VERSION${NC}"

            # 卸载旧版本
            if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
                apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
                apt-get update -y
                # 添加官方源
                add_docker_gpg_key
                echo "deb [arch=$ARCH signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                # 安装官方版（锁定大版本 29.x）
                apt-get update -y
                apt-get install -y docker-ce=29.* docker-ce-cli=29.* containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || \
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
            elif [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
                yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
                # 添加官方源
                add_docker_gpg_key
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                # 安装官方版
                yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
            fi

        # 方案2：安装系统自带版（docker.io）
        else
            echo -e "${YELLOW}▶ 系统版本/内核过低，安装系统自带版 Docker${NC}"
            echo -e "${YELLOW}  - 内核版本：$kernel_version (< $min_kernel)${NC}"
            echo -e "${YELLOW}  - 系统版本：$DISTRO $DISTRO_VERSION${NC}"
            
            if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
                apt-get update -y
                apt-get install -y docker.io -y
                # 使用多源函数下载 Compose
                download_docker_compose
            elif [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
                yum install -y docker -y
                # CentOS/RHEL 也使用多源下载 Compose
                download_docker_compose
            fi
        fi

        # 启动 Docker 服务
        echo -e "${YELLOW}▶ 启动 Docker 服务...${NC}"
        systemctl enable --now docker 2>/dev/null || true

        # 修复：验证安装（更智能的 Compose 版本检测，并添加权限检测）
        echo -e "${YELLOW}▶ 验证安装结果...${NC}"
        if docker --version &>/dev/null; then
            local new_version=$(docker --version | awk '{print $3}' | sed 's/,//')
            echo -e "${GREEN}✅ Docker 安装/更新完成！${NC}"
            echo -e "${GREEN}Docker 版本：${new_version}${NC}"
            
            # 如果是从旧版本更新过来的，显示版本变化
            if [[ -n "$current_docker_version" && "$current_docker_version" != "$new_version" ]]; then
                echo -e "${GREEN}  版本变化：${current_docker_version} → ${new_version}${NC}"
            fi
            
            # 修复：先检测 Docker Compose 插件（新版）
            if docker compose version &>/dev/null; then
                local new_compose_version=$(docker compose version --short 2>/dev/null || docker compose version | awk '{print $4}')
                echo -e "${GREEN}Docker Compose 版本：${new_compose_version}${NC}"
                if [[ -n "$current_compose_version" && "$current_compose_version" != "$new_compose_version" ]]; then
                    echo -e "${GREEN}  版本变化：${current_compose_version} → ${new_compose_version}${NC}"
                fi
            # 其次检测独立 docker-compose（旧版）
            elif command -v docker-compose &>/dev/null; then
                if docker-compose --version &>/dev/null; then
                    local new_compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
                    echo -e "${GREEN}Docker Compose 版本：${new_compose_version}${NC}"
                    if [[ -n "$current_compose_version" && "$current_compose_version" != "$new_compose_version" ]]; then
                        echo -e "${GREEN}  版本变化：${current_compose_version} → ${new_compose_version}${NC}"
                    fi
                else
                    echo -e "${RED}Docker Compose 文件存在但无法执行，可能已损坏${NC}"
                    echo -e "${YELLOW}建议重新运行安装或手动修复${NC}"
                fi
            else
                echo -e "${YELLOW}Docker Compose 未安装${NC}"
            fi
        else
            echo -e "${RED}❌ Docker 安装失败${NC}"
        fi
    }

    # 执行智能安装
    install_docker_smart

    pause
    show_menu
}

# 3.更新Docker容器管理
update_menu() {
    while true; do
        clear
        echo -e "${GREEN}    Docker容器更新管理    ${NC}"
	echo -e "${GREEN}=========================${NC}"
        echo "1. 手动选择更新容器"
        echo "2. 自动更新所有容器"
        echo "3. 更新指定容器"
        echo "0. 返回"
        
        read -p "请输入选项: " choice
        case $choice in
            1)
                echo -e "${CYAN}正在运行的容器列表：${NC}"
                docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" || true
                read -p "输入要更新的容器名称（多个用空格分隔）: " -a containers
                for container in "${containers[@]}"; do
                    safe_update_container "$container" false
                done
                ;;
            2)
                echo -e "${CYAN}正在批量更新所有容器...${NC}"
                # 兼容 Bash 3（替换 mapfile）
                local containers=$(docker ps -q)
                for container in $containers; do
                    safe_update_container "$(docker inspect --format '{{.Name}}' "$container" | sed 's/^\///')" true
                done
                ;;
            3)
                read -p "输入要更新的容器名称: " target
                safe_update_container "$target" false
                ;;
            0)
               show_menu
                ;;
            *)
                echo -e "${RED}无效选项！${NC}"
                ;;
        esac
        pause
    done
}

# 安全更新容器函数
safe_update_container() {
    local container=$1
    local auto_mode=${2:-false}

    # 空容器名检查
    if [ -z "$container" ]; then
        echo -e "${RED}错误：未指定容器名称！${NC}"
        return 1
    fi

    # 容器存在性检查
    if ! docker inspect "$container" &>/dev/null; then
        echo -e "${RED}错误：容器 '$container' 不存在！${NC}"
        echo -e "${CYAN}可用容器列表：${NC}"
        docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}' | column -t || true
        echo -e "${NC}"
        return 1
    fi

    echo -e "\n${CYAN}=== 正在处理容器: $container ===${NC}"

    # 获取容器配置
    local image=$(docker inspect --format '{{.Config.Image}}' "$container" | cut -d'@' -f1)
    local volumes=$(docker inspect --format '{{ range .Mounts }}-v {{ .Source }}:{{ .Destination }} {{ end }}' "$container")
    # ========== 优化5：更可靠的端口解析 ==========
    local ports=""
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local port_map=$(echo "$line" | sed -e 's/=/:/' -e 's/\/tcp//' -e 's/\/udp//')
            ports="$ports -p $port_map"
        fi
    done < <(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}}={{index $conf 0.HostPort}}{{end}} {{end}}' "$container" 2>/dev/null | tr ' ' '\n' | grep -v '^$')
    
    local envs=$(docker inspect --format '{{ range .Config.Env }}--env {{ . }} {{ end }}' "$container")
    local restart_policy=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$container")
    local network=$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$container")

    # 检查镜像更新（增加超时）
    echo -e "${YELLOW}▶ 正在检查镜像更新...${NC}"
    if ! timeout 300 docker pull "$image" >/dev/null 2>&1; then
        echo -e "${RED}✖ 镜像拉取失败: $image${NC}"
        return 1
    fi

    # 判断是否需要更新
    local old_image_id=$(docker inspect --format '{{.Image}}' "$container")
    local new_image_id=$(docker inspect --format '{{.Id}}' "$image" 2>/dev/null || echo "")
    if [ "$old_image_id" == "$new_image_id" ] || [ -z "$new_image_id" ]; then
        echo -e "${YELLOW}✔ 当前已是最新版本${NC}"
        return 0
    fi

    # 手动模式确认
    if [ "$auto_mode" = "false" ] && ! confirm_action "确认更新容器 $container 吗？"; then
        return 0
    fi

    # 创建临时容器
    local new_name="${container}_tmp_$(date +%s)"
    echo -e "${CYAN}▶ 正在创建临时容器: $new_name${NC}"
    # ========== 优化8：更详细的错误信息 ==========
    if ! docker run -d \
        --name "$new_name" \
        --restart "$restart_policy" \
        --network "$network" \
        $volumes \
        $ports \
        $envs \
        "$image" >/dev/null 2>&1; then
        
        local error_msg=$(docker logs "$new_name" 2>&1 | head -20)
        echo -e "${RED}✖ 临时容器创建失败！错误信息：${NC}"
        echo "$error_msg"
        docker rm -f "$new_name" 2>/dev/null || true
        return 1
    fi

    # 替换旧容器（增加错误处理）
    echo -e "${CYAN}▶ 正在替换旧容器...${NC}"
    if ! docker stop "$container" >/dev/null 2>&1; then
        echo -e "${RED}✖ 停止旧容器失败，回滚操作${NC}"
        docker rm -f "$new_name" 2>/dev/null || true
        return 1
    fi
    docker rm "$container" >/dev/null 2>&1 || true
    docker rename "$new_name" "$container" >/dev/null 2>&1 || true

    echo -e "${GREEN}✔ 容器 $container 更新成功！${NC}"
}

# 4. Docker智能清理（完整集成）
docker_cleanup() {
    # 环境检查
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}错误：未检测到Docker环境${NC}"
        pause
        show_menu
    fi

    # 清理子菜单
    show_cleanup_menu() {
        clear
        echo -e "${CYAN}=== Docker智能清理 ===${NC}"
        echo "1. 显示磁盘使用情况"
        echo "2. 执行全面清理"
        echo "3. 自定义清理项目"
        echo "0. 返回主菜单"
        read -p "请输入选项: " sub_option
        case $sub_option in
            1) show_disk_usage ; pause ; show_cleanup_menu ;;
            2) full_cleanup ;;
            3) custom_cleanup ;;
            0) show_menu ;;
            *) echo -e "${RED}无效选项！${NC}" ; pause ; show_cleanup_menu ;;
        esac
    }

    # 显示磁盘使用
    show_disk_usage() {
        echo -e "\n${CYAN}=== 当前Docker磁盘使用 ===${NC}"
        docker system df --format '{
            "类型": "{{.Type}}",
            "总数": "{{.TotalCount}}",
            "活跃数": "{{.ActiveCount}}",
            "大小": "{{.Size}}",
            "可回收": "{{.Reclaimable}}"
        }' | awk -F'"' 'BEGIN {
            printf "%-10s %-8s %-8s %-12s %-12s\n","类型","总数","活跃","大小","可回收"
        }
        NR>1 {
            gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$4)
            gsub(/^ +| +$/,"",$6); gsub(/^ +| +$/,"",$8)
            gsub(/^ +| +$/,"",$10)
            printf "%-10s %-8s %-8s %-12s %-12s\n",$2,$4,$6,$8,$10
        }'
    }

    # 全面清理
    full_cleanup() {
        if ! confirm_action "确认要进行全面清理吗？(包括容器/镜像/网络/卷)"; then
            echo -e "${YELLOW}已取消全面清理${NC}"
            pause
            show_cleanup_menu
            return
        fi
        
        echo -e "${GREEN}◆ 开始全面清理...${NC}"
        docker system prune -a --volumes -f
        echo -e "${GREEN}✓ 全面清理完成！${NC}"
        show_disk_usage
        pause
        show_cleanup_menu
    }

    # 自定义清理
    custom_cleanup() {
        clear
        echo -e "${CYAN}=== 自定义清理选项 ===${NC}"
        echo "1. 清理构建缓存"
        echo "2. 清理停止的容器"
        echo "3. 清理未使用镜像"
        echo "4. 清理孤立网络"
        echo "5. 清理未使用卷"
        echo "0. 返回上级"
        read -p "请选择要清理的项目: " custom_option
        case $custom_option in
            1) clean_build_cache ;;
            2) clean_containers ;;
            3) clean_images ;;
            4) clean_networks ;;
            5) clean_volumes ;;
            0) show_cleanup_menu ;;
            *) echo -e "${RED}无效选项！${NC}" ; pause ; custom_cleanup ;;
        esac
    }

    # 清理构建缓存
    clean_build_cache() {
        echo -e "${GREEN}◆ 清理构建缓存...${NC}"
        docker builder prune -f
        echo -e "${GREEN}✓ 构建缓存已清理${NC}"
        pause
        custom_cleanup
    }

    # 清理停止的容器
    clean_containers() {
        if confirm_action "确定要清理所有停止的容器吗？"; then
            echo -e "${GREEN}◆ 清理停止的容器...${NC}"
            docker container prune -f
        else
            echo -e "${YELLOW}已取消容器清理${NC}"
        fi
        pause
        custom_cleanup
    }

    # 清理镜像
    clean_images() {
        clear
        echo -e "${CYAN}=== 镜像清理选项 ===${NC}"
        echo "1. 仅清理悬空镜像"
        echo "2. 清理所有未使用镜像"
        echo "0. 返回上级"
        read -p "请选择清理方式: " img_choice
        case $img_choice in
            1) docker image prune -f ; echo -e "${GREEN}✓ 悬空镜像已清理${NC}" ;;
            2) docker image prune -a -f ; echo -e "${GREEN}✓ 未使用镜像已清理${NC}" ;;
            0) custom_cleanup ; return ;;
            *) echo -e "${RED}无效选择！${NC}" ;;
        esac
        pause
        custom_cleanup
    }

    # 清理网络
    clean_networks() {
        echo -e "${GREEN}◆ 清理孤立网络...${NC}"
        docker network prune -f
        pause
        custom_cleanup
    }

    # 清理卷
    clean_volumes() {
        if confirm_action "确定要清理未使用的卷吗？"; then
            echo -e "${GREEN}◆ 清理未使用卷...${NC}"
            docker volume prune -f
        else
            echo -e "${YELLOW}已取消卷清理${NC}"
        fi
        pause
        custom_cleanup
    }

    show_cleanup_menu
}

# 5. Docker 容器管理
docker_container_management() {
    echo -e "${GREEN}Docker容器管理${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo "1. 启动容器"
    echo "2. 停止容器"
    echo "3. 启动所有容器"
    echo "4. 停止所有容器"
    echo "5. 创建指定容器"
    echo "6. 删除指定容器"
	echo "7. 删除所有容器"
    echo "0. 返回"
    read -p "请输入选项: " container_option
    case $container_option in
        1) start_container ;;
        2) stop_container ;;
        3) start_all_containers ;;
        4) stop_all_containers ;;
        5) create_new_container ;;
        6) remove_specified_container ;;
		7) remove_all_containers ;;
        0) show_menu ;;
        *) echo "无效选项，请重新选择" && docker_container_management ;;
    esac
}

# 启动容器
start_container() {
    read -p "请输入要启动的容器 ID 或名称: " container_id
    if [ -z "$container_id" ]; then
        docker_container_management
    fi
    docker start $container_id || echo -e "${RED}启动容器失败${NC}"
    echo -e "${GREEN}容器 $container_id 已启动！${NC}"
    pause
    docker_container_management
}

# 停止容器
stop_container() {
    read -p "请输入要停止的容器 ID 或名称: " container_id
    if [ -z "$container_id" ]; then
        docker_container_management
    fi
    docker stop $container_id || echo -e "${RED}停止容器失败${NC}"
    echo -e "${GREEN}容器 $container_id 已停止！${NC}"
    pause
    docker_container_management
}

# 启动所有容器（增加空值处理）
start_all_containers() {
    local container_ids=$(docker ps -a -q)
    if [ -z "$container_ids" ]; then
        echo -e "${YELLOW}没有可启动的容器${NC}"
    else
        docker start $container_ids || echo -e "${RED}部分容器启动失败${NC}"
        echo -e "${GREEN}所有容器已启动！${NC}"
    fi
    pause
    docker_container_management
}

# 停止所有容器（增加空值处理）
stop_all_containers() {
    local container_ids=$(docker ps -q)
    if [ -z "$container_ids" ]; then
        echo -e "${YELLOW}没有运行中的容器${NC}"
    else
        docker stop $container_ids || echo -e "${RED}部分容器停止失败${NC}"
        echo -e "${GREEN}所有容器已停止！${NC}"
    fi
    pause
    docker_container_management
}

# 创建指定容器
create_new_container() {
    read -p "请输入新容器的镜像名称: " image_name
    if [ -z "$image_name" ]; then
        docker_container_management
    fi
    read -p "请输入新容器的名称（可选）: " container_name
    if [ -z "$container_name" ]; then
        container_name="auto_$(date +%s)"
        echo -e "${YELLOW}未输入容器名称，自动生成：$container_name${NC}"
    fi
    # 检查容器名称是否已存在
    if docker inspect "$container_name" &>/dev/null; then
        echo -e "${RED}容器名称 $container_name 已存在${NC}"
        docker_container_management
    fi
    docker run -d --name $container_name $image_name || echo -e "${RED}创建容器失败${NC}"
    echo -e "${GREEN}新容器已创建！${NC}"
    pause
    docker_container_management
}

# 删除指定容器
remove_specified_container() {
    read -p "请输入要删除的容器 ID 或名称: " container_id
    if [ -z "$container_id" ]; then
        docker_container_management
    fi
    docker rm -f $container_id || echo -e "${RED}删除容器失败${NC}"
    echo -e "${GREEN}容器 $container_id 已删除！${NC}"
    pause
    docker_container_management
}

# 删除所有容器（增加确认和空值处理）
remove_all_containers() {
    local container_count=$(docker ps -a -q | wc -l | awk '{print $1}')
    if [ "$container_count" -eq 0 ]; then
        echo -e "${YELLOW}没有可删除的容器${NC}"
        pause
        docker_container_management
        return
    fi
    read -p "您确定要删除所有 $container_count 个容器吗？[y/n]: " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        docker rm -f $(docker ps -a -q) || echo -e "${RED}部分容器删除失败${NC}"
        echo -e "${GREEN}所有容器已删除！${NC}"
    else
        echo -e "${YELLOW}已取消删除操作${NC}"
    fi
    pause
    docker_container_management
}

# 6. Docker 镜像管理
docker_image_management() {
    echo -e "${GREEN}Docker镜像管理${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo "1. 删除指定镜像"
    echo "2. 创建指定容器"
    echo "3. 删除所有镜像"
    echo "0. 返回"
    read -p "请输入选项: " image_option
    case $image_option in
        1) remove_specified_image ;;
        2) create_new_container ;;
        3) remove_all_images ;;
        0) show_menu ;;
        *) echo "无效选项，请重新选择" && docker_image_management ;;
    esac
}

# 删除指定镜像
remove_specified_image() {
    read -p "请输入要删除的镜像 ID 或名称: " image_id
    if [ -z "$image_id" ]; then
        docker_image_management
    fi
    docker rmi -f $image_id || echo -e "${RED}删除镜像失败（可能被容器引用）${NC}"
    echo -e "${GREEN}镜像 $image_id 已删除！${NC}"
    pause
    docker_image_management
}

# 删除所有镜像（增加空值处理）
remove_all_images() {
    local image_count=$(docker images -q | wc -l | awk '{print $1}')
    if [ "$image_count" -eq 0 ]; then
        echo -e "${YELLOW}没有可删除的镜像${NC}"
        pause
        docker_image_management
        return
    fi
    docker rmi -f $(docker images -q) || echo -e "${RED}部分镜像删除失败（可能被容器引用）${NC}"
    echo -e "${GREEN}所有可删除的镜像已删除！${NC}"
    pause
    docker_image_management
}

# 7. Docker 网络管理
docker_network_management() {
    echo -e "${GREEN}Docker网络管理${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo "1. 创建网络"
    echo "2. 加入网络"
    echo "3. 退出网络"
    echo "4. 删除网络"
    echo "0. 返回"
    read -p "请输入选项: " network_option
    case $network_option in
        1) create_network ;;
        2) join_network ;;
        3) leave_network ;;
        4) delete_network ;;
        0) show_menu ;;
        *) echo "无效选项，请重新选择" && docker_network_management ;;
    esac
}

# 创建 Docker 网络（增加检查）
create_network() {
    read -p "请输入要创建的网络名称: " network_name
    if [ -z "$network_name" ]; then
        docker_network_management
    fi
    if docker inspect "$network_name" &>/dev/null; then
        echo -e "${RED}网络 $network_name 已存在${NC}"
        docker_network_management
    fi
    docker network create $network_name || echo -e "${RED}创建网络失败${NC}"
    echo -e "${GREEN}网络 $network_name 已创建！${NC}"
    pause
    docker_network_management
}

# 加入 Docker 网络
join_network() {
    read -p "请输入要加入的容器 ID 或名称: " container_id
    if [ -z "$container_id" ]; then
        docker_network_management
    fi
    read -p "请输入要加入的网络名称: " network_name
    if [ -z "$network_name" ]; then
        docker_network_management
    fi
    docker network connect $network_name $container_id || echo -e "${RED}加入网络失败${NC}"
    echo -e "${GREEN}容器 $container_id 已加入网络 $network_name！${NC}"
    pause
    docker_network_management
}

# 退出 Docker 网络
leave_network() {
    read -p "请输入要退出的容器 ID 或名称: " container_id
    if [ -z "$container_id" ]; then
        docker_network_management
    fi
    read -p "请输入要退出的网络名称: " network_name
    if [ -z "$network_name" ]; then
        docker_network_management
    fi
    docker network disconnect $network_name $container_id || echo -e "${RED}退出网络失败${NC}"
    echo -e "${GREEN}容器 $container_id 已退出网络 $network_name！${NC}"
    pause
    docker_network_management
}

# 删除 Docker 网络
delete_network() {
    read -p "请输入要删除的网络名称: " network_name
    if [ -z "$network_name" ]; then
        docker_network_management
    fi
    docker network rm $network_name || echo -e "${RED}删除网络失败（可能被容器使用）${NC}"
    echo -e "${GREEN}网络 $network_name 已删除！${NC}"
    pause
    docker_network_management
}

# 8. Docker 卷管理
docker_volume_management() {
    echo -e "${GREEN}Docker卷管理${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo "1. 创建新卷"
    echo "2. 删除指定卷"
    echo "3. 删除所有卷"
    echo "0. 返回"
    read -p "请输入选项: " volume_option
    case $volume_option in
        1) create_volume ;;
        2) delete_specified_volume ;;
        3) delete_all_volumes ;;
        0) show_menu ;;
        *) echo "无效选项，请重新选择" && docker_volume_management ;;
    esac
}

# 创建新卷（增加检查）
create_volume() {
    read -p "请输入要创建的新卷名称: " volume_name
    if [ -z "$volume_name" ]; then
        docker_volume_management
    fi
    if docker inspect "$volume_name" &>/dev/null; then
        echo -e "${RED}卷 $volume_name 已存在${NC}"
        docker_volume_management
    fi
    docker volume create $volume_name || echo -e "${RED}创建卷失败${NC}"
    echo -e "${GREEN}新卷 $volume_name 已创建！${NC}"
    pause
    docker_volume_management
}

# 删除指定卷
delete_specified_volume() {
    read -p "请输入要删除的卷名称: " volume_name
    if [ -z "$volume_name" ]; then
        docker_volume_management
    fi
    docker volume rm $volume_name || echo -e "${RED}删除卷失败（可能被容器使用）${NC}"
    echo -e "${GREEN}卷 $volume_name 已删除！${NC}"
    pause
    docker_volume_management
}

# ========== 优化4：卷删除空值处理 ==========
# 删除所有卷
delete_all_volumes() {
    local volumes=$(docker volume ls -q)
    local volume_count=$(echo "$volumes" | wc -l | awk '{print $1}')
    if [ "$volume_count" -eq 0 ]; then
        echo -e "${YELLOW}没有可删除的卷${NC}"
        pause
        docker_volume_management
        return
    fi
    read -p "您确定要删除所有 $volume_count 个卷吗？(数据将永久删除)[y/n]: " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        if [ -n "$volumes" ]; then
            docker volume rm $volumes || echo -e "${RED}部分卷删除失败（可能被容器使用）${NC}"
        fi
        echo -e "${GREEN}所有可删除的卷已删除！${NC}"
    else
        echo -e "${YELLOW}已取消删除操作${NC}"
    fi
    pause
    docker_volume_management
}

# 9. 卸载 Docker 环境的函数
uninstall_docker_environment() {
    read -p "您确定要卸载 Docker 吗？此操作将删除所有 Docker 容器、镜像及数据。请输入 y 确认：" confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        # 执行 Docker 卸载操作
        clean_docker_containers_images
        uninstall_docker
        delete_docker_files
        delete_docker_user_group
        delete_docker_install_script
        echo -e "${GREEN}Docker 环境已卸载并清理完成！${NC}"
        pause
        show_menu
    else
        echo "取消卸载操作。"
        pause
        show_menu
    fi
}

# 检测系统类型
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=$ID
fi

# 停止并删除 Docker 容器和镜像（增加错误重定向）
function clean_docker_containers_images {
    echo "停止并删除所有容器和镜像..."
    sudo docker stop $(sudo docker ps -a -q) 2>/dev/null || true
    sudo docker rm $(sudo docker ps -a -q) 2>/dev/null || true
    sudo docker rmi $(sudo docker images -q) 2>/dev/null || true
}

# 卸载 Docker 对应的包（增加错误处理）
function uninstall_docker {
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        echo "卸载 Docker（适用于 Ubuntu/Debian）..."
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
        sudo apt-get purge -y docker.io 2>/dev/null || true
    elif [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
        echo "卸载 Docker（适用于 CentOS/RHEL）..."
        sudo yum remove -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
    else
        echo "不支持的操作系统。"
        exit 1
    fi
}

# 删除 Docker 相关文件和目录（增加错误重定向）
function delete_docker_files {
    echo "删除 Docker 配置和数据文件..."
    sudo rm -rf /var/lib/docker 2>/dev/null || true
    sudo rm -rf /var/lib/containerd 2>/dev/null || true
    sudo rm -rf /etc/docker 2>/dev/null || true
    sudo rm -rf /var/run/docker 2>/dev/null || true
}

# 删除 Docker 用户和组（可选，增加错误重定向）
function delete_docker_user_group {
    echo "删除 Docker 用户和组..."
    sudo deluser docker 2>/dev/null || true
    sudo delgroup docker 2>/dev/null || true
}

# 删除 Docker 安装脚本文件（如果存在）
function delete_docker_install_script {
    if [[ -f /get-docker.sh ]]; then
        echo "删除 Docker 安装脚本文件..."
        sudo rm -f /get-docker.sh 2>/dev/null || true
    fi
}

# 暂停，按任意键继续
pause() {
    # 设置绿色文本颜色
    echo -e "\033[0;32m操作完成，按任意键继续...\033[0m"
    read -n 1 -s -r
}

# 启动脚本（增加权限检查）
check_docker_permission
show_menu
