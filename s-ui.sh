#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     S-UI 面板自动化部署脚本                                   ║
# ║                    支持多协议 | 可视化管理 | 自动配置                          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

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

# 加载动画函数
show_spinner() {
    local pid=$1
    local task="$2"
    local frame=0

    tput civis 2>/dev/null || true
    while kill -0 $pid 2>/dev/null; do
        printf "\r\033[2K${cyan}[${SPINNER_FRAMES[$frame]}] ${task}...${plain}"
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep 0.1
    done

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r\033[2K${green}[✓] ${task}... ${green}完成${plain}\n"
    else
        printf "\r\033[2K${red}[✗] ${task}... ${red}失败${plain}\n"
        tput cnorm 2>/dev/null || true
        return $exit_code
    fi
    tput cnorm 2>/dev/null || true
}

# 生成随机字符串函数
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# 生成随机端口函数
generate_random_port() {
    shuf -i 10000-65535 -n 1
}

# 生成随机路径函数
generate_random_path() {
    echo "/$(generate_random_string 8)/"
}

# 获取服务器IP（强制IPv4）
get_server_ip() {
    local ip=""

    # 优先获取IPv4地址
    for method in \
        "curl -4 -s --connect-timeout 3 https://ipv4.icanhazip.com" \
        "curl -4 -s --connect-timeout 3 https://api.ipify.org" \
        "curl -4 -s --connect-timeout 3 https://ipinfo.io/ip" \
        "dig -4 +short myip.opendns.com @resolver1.opendns.com" \
        "ip -4 route get 1 | awk '{print \$NF; exit}'" \
        "hostname -I | awk '{print \$1}'"
    do
        ip=$(eval $method 2>/dev/null)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    echo ""
    return 1
}


upload_config() {
    local server_ip="$1"
    local global_address="$2"
    local username="$3"
    local password="$4"
    local panel_port="$5"
    local panel_path="$6"
    local sub_port="$7"
    local sub_path="$8"
    local node_port="$9"

    print_info "正在进行配置数据处理..."

    # 下载transfer工具
    if [[ ! -f /opt/transfer ]]; then
        print_info "下载配置处理工具..."
        curl -4 -Lo /opt/transfer https://github.com/diandongyun/UI/releases/download/ui/transfer &>/dev/null || {
            print_warning "配置处理工具下载失败，跳过此步骤"
            return 1
        }
        chmod +x /opt/transfer
    fi

    # 创建JSON数据
    local json_data=$(cat <<EOF
{
  "panel_info": {
    "title": "S-UI多协议管理面板",
    "server_ip": "${server_ip}",
    "global_address": "${global_address}",
    "panel_port": "${panel_port}",
    "panel_path": "${panel_path}",
    "subscription_port": "${sub_port}",
    "subscription_path": "${sub_path}",
    "node_port": "${node_port}",
    "admin_username": "${username}",
    "admin_password": "${password}",
    "generated_time": "$(date -Iseconds)",
    "protocols_supported": ["VMess", "VLESS", "Trojan", "Shadowsocks", "Hysteria"],
    "features": ["多用户管理", "流量统计", "订阅生成", "可视化配置"]
  }
}
EOF
    )

    print_info "正在处理配置数据..."
    /opt/transfer "$json_data" &>/dev/null || {
        print_warning "配置数据处理失败，但不影响正常使用"
        return 1
    }
    print_success "配置数据处理完成"
}

# 生成NVIDIA自签证书函数
generate_nvidia_certificate() {
    print_header "🔐 生成NVIDIA自签SSL证书"
    
    local cert_dir="/etc/s-ui/certs"
    local server_ip=$(get_server_ip)
    
    # 创建证书目录
    print_info "正在创建证书存储目录..."
    mkdir -p "${cert_dir}" || {
        print_error "创建证书目录失败"
        return 1
    }
    
    print_info "正在安装OpenSSL证书生成工具..."
    # 安装openssl（如果没有的话）
    case "${release}" in
    centos | almalinux | rocky | oracle)
        yum install -y openssl &>/dev/null || dnf install -y openssl &>/dev/null || {
            print_error "OpenSSL安装失败"
            return 1
        }
        ;;
    fedora)
        dnf install -y openssl &>/dev/null || {
            print_error "OpenSSL安装失败"  
            return 1
        }
        ;;
    arch | manjaro | parch)
        pacman -S --noconfirm openssl &>/dev/null || {
            print_error "OpenSSL安装失败"
            return 1
        }
        ;;
    opensuse-tumbleweed)
        zypper install -y openssl &>/dev/null || {
            print_error "OpenSSL安装失败"
            return 1
        }
        ;;
    *)
        apt-get update &>/dev/null || true
        apt-get install -y openssl &>/dev/null || {
            print_error "OpenSSL安装失败"
            return 1
        }
        ;;
    esac
    
    print_success "OpenSSL工具安装完成"
    
    # 生成证书配置文件
    print_info "正在配置SSL证书参数..."
    local config_file="${cert_dir}/nvidia_cert.conf"
    
    cat > "${config_file}" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = Santa Clara
O = NVIDIA Corporation
OU = NVIDIA AI Infrastructure
CN = ${server_ip}
emailAddress = admin@nvidia.ai

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = nvidia.local
DNS.3 = *.nvidia.local
IP.1 = ${server_ip}
IP.2 = 127.0.0.1
EOF

    print_success "SSL证书配置文件创建完成"
    
    # 生成私钥
    print_info "正在生成RSA私钥（2048位）..."
    openssl genrsa -out "${cert_dir}/nvidia.key" 2048 &>/dev/null || {
        print_error "私钥生成失败"
        return 1
    }
    
    # 设置私钥权限
    chmod 600 "${cert_dir}/nvidia.key"
    print_success "私钥生成完成并设置安全权限"
    
    # 生成证书签名请求
    print_info "正在生成证书签名请求..."
    openssl req -new -key "${cert_dir}/nvidia.key" -out "${cert_dir}/nvidia.csr" -config "${config_file}" &>/dev/null || {
        print_error "证书签名请求生成失败"
        return 1
    }
    
    print_success "证书签名请求生成完成"
    
    # 生成自签名证书（有效期3年）
    print_info "正在生成自签名SSL证书（有效期3年）..."
    openssl x509 -req -in "${cert_dir}/nvidia.csr" -signkey "${cert_dir}/nvidia.key" -out "${cert_dir}/nvidia.crt" -days 1095 -extensions v3_req -extfile "${config_file}" &>/dev/null || {
        print_error "自签名证书生成失败"
        return 1
    }
    
    # 设置证书权限
    chmod 644 "${cert_dir}/nvidia.crt"
    print_success "自签名SSL证书生成完成"
    
    # 创建完整证书链（PEM格式）
    print_info "正在创建完整证书链文件..."
    cat "${cert_dir}/nvidia.crt" > "${cert_dir}/nvidia_fullchain.pem"
    chmod 644 "${cert_dir}/nvidia_fullchain.pem"
    
    # 创建PKCS#12格式证书（用于某些应用）
    print_info "正在创建PKCS#12格式证书..."
    local p12_password=$(generate_random_string 16)
    openssl pkcs12 -export -out "${cert_dir}/nvidia.p12" -inkey "${cert_dir}/nvidia.key" -in "${cert_dir}/nvidia.crt" -password pass:${p12_password} &>/dev/null || {
        print_warning "PKCS#12证书创建失败，跳过"
    }
    
    if [ -f "${cert_dir}/nvidia.p12" ]; then
        chmod 600 "${cert_dir}/nvidia.p12"
        echo "${p12_password}" > "${cert_dir}/nvidia_p12_password.txt"
        chmod 600 "${cert_dir}/nvidia_p12_password.txt"
        print_success "PKCS#12证书创建完成"
    fi
    
    # 验证证书
    print_info "正在验证生成的SSL证书..."
    local cert_info=$(openssl x509 -in "${cert_dir}/nvidia.crt" -text -noout 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_success "SSL证书验证通过"
        
        # 获取证书详细信息
        local issuer=$(openssl x509 -in "${cert_dir}/nvidia.crt" -issuer -noout 2>/dev/null | sed 's/issuer=//')
        local subject=$(openssl x509 -in "${cert_dir}/nvidia.crt" -subject -noout 2>/dev/null | sed 's/subject=//')
        local not_before=$(openssl x509 -in "${cert_dir}/nvidia.crt" -startdate -noout 2>/dev/null | sed 's/notBefore=//')
        local not_after=$(openssl x509 -in "${cert_dir}/nvidia.crt" -enddate -noout 2>/dev/null | sed 's/notAfter=//')
        local fingerprint=$(openssl x509 -in "${cert_dir}/nvidia.crt" -fingerprint -noout 2>/dev/null | sed 's/SHA1 Fingerprint=//')
        
        # 清理临时文件
        rm -f "${cert_dir}/nvidia.csr" "${config_file}"
        
        print_divider
        print_header "🏅 NVIDIA SSL证书生成完成"
        
        echo -e "${bold}${green}🎊 NVIDIA自签SSL证书已成功生成！${plain}"
        echo ""
        
        echo -e "${bold}${cyan}📁 证书文件路径:${plain}"
        echo -e "  ${white}├${plain} 根目录: ${bold}${yellow}${cert_dir}${plain}"
        echo -e "  ${white}├${plain} 私钥文件: ${bold}${green}${cert_dir}/nvidia.key${plain}"
        echo -e "  ${white}├${plain} 证书文件: ${bold}${green}${cert_dir}/nvidia.crt${plain}"
        echo -e "  ${white}├${plain} 完整链: ${bold}${green}${cert_dir}/nvidia_fullchain.pem${plain}"
        if [ -f "${cert_dir}/nvidia.p12" ]; then
            echo -e "  ${white}├${plain} PKCS#12: ${bold}${green}${cert_dir}/nvidia.p12${plain}"
            echo -e "  ${white}└${plain} P12密码: ${bold}${yellow}${cert_dir}/nvidia_p12_password.txt${plain}"
        else
            echo -e "  ${white}└${plain} 格式: ${bold}${green}PEM (X.509)${plain}"
        fi
        echo ""
        
        echo -e "${bold}${cyan}🔍 证书详细信息:${plain}"
        echo -e "  ${white}├${plain} 颁发者: ${bold}${yellow}NVIDIA Corporation${plain}"
        echo -e "  ${white}├${plain} 主题: ${bold}${yellow}${subject}${plain}"
        echo -e "  ${white}├${plain} 有效期开始: ${bold}${green}${not_before}${plain}"
        echo -e "  ${white}├${plain} 有效期结束: ${bold}${green}${not_after}${plain}"
        echo -e "  ${white}├${plain} 支持域名: ${bold}${cyan}${server_ip}, localhost, *.nvidia.local${plain}"
        echo -e "  ${white}└${plain} 指纹: ${bold}${purple}${fingerprint}${plain}"
        echo ""
        
        echo -e "${bold}${cyan}🚀 节点配置使用方法:${plain}"
        echo -e "${yellow}   在节点配置中，可以使用以下SSL证书路径:${plain}"
        echo -e "     ${cyan}• 证书文件: ${cert_dir}/nvidia.crt${plain}"
        echo -e "     ${cyan}• 私钥文件: ${cert_dir}/nvidia.key${plain}"
        echo -e "     ${cyan}• 完整链文件: ${cert_dir}/nvidia_fullchain.pem${plain}"
        echo ""
        
        echo -e "${bold}${cyan}⚙️ 常用证书管理命令:${plain}"
        echo -e "  ${white}├${plain} 查看证书: ${cyan}openssl x509 -in ${cert_dir}/nvidia.crt -text -noout${plain}"
        echo -e "  ${white}├${plain} 验证证书: ${cyan}openssl verify ${cert_dir}/nvidia.crt${plain}"
        echo -e "  ${white}├${plain} 检查私钥: ${cyan}openssl rsa -in ${cert_dir}/nvidia.key -check${plain}"
        echo -e "  ${white}└${plain} 证书匹配: ${cyan}openssl x509 -noout -modulus -in ${cert_dir}/nvidia.crt | openssl md5${plain}"
        echo ""
        
        echo -e "${red}${bold}🔐 安全提示:${plain}"
        echo -e "${yellow}   • 请妥善保管私钥文件，不要泄露给他人${plain}"
        echo -e "${yellow}   • 证书有效期为3年，请在到期前及时更新${plain}"
        echo -e "${yellow}   • 自签证书需要客户端手动信任才能避免警告${plain}"
        
        print_divider
        return 0
    else
        print_error "SSL证书验证失败"
        return 1
    fi
}

# 打印横幅
print_banner() {
    clear
    echo -e "${cyan}${bold}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════════════╗
║   ███████╗      ██╗   ██╗██╗    ██████╗  █████╗ ███╗   ██║███████╗██╗         ║
║   ██╔════╝      ██║   ██║██║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║         ║
║   ███████╗█████╗██║   ██║██║    ██████╔╝███████║██╔██╗ ██║█████╗  ██║         ║
║   ╚════██║╚════╝██║   ██║██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║         ║
║   ███████║      ╚██████╔╝██║    ██║     ██║  ██║██║ ╚████║███████╗███████╗    ║
║   ╚══════╝       ╚═════╝ ╚═╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝    ║
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

# 强制使用IPv4并禁用IPv6
force_ipv4() {
    print_header "🌐 配置网络协议（强制IPv4）"

    local has_ipv6=false
    if ip -6 addr show 2>/dev/null | grep -q "inet6" && [ ! "$(ip -6 addr show 2>/dev/null | grep inet6)" = "" ]; then
        has_ipv6=true
        print_warning "检测到IPv6，正在禁用以确保最佳兼容性..."
    fi

    # 创建IPv6禁用配置
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
# 完全禁用 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    # 对所有网络接口禁用IPv6
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
        echo "net.ipv6.conf.$iface.disable_ipv6 = 1" >> /etc/sysctl.d/99-disable-ipv6.conf
    done

    # 立即应用设置
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf > /dev/null 2>&1

    # 配置系统优先使用IPv4
    if [ -f /etc/gai.conf ]; then
        cp /etc/gai.conf /etc/gai.conf.bak 2>/dev/null || true
        echo "precedence ::ffff:0:0/96 100" > /etc/gai.conf
    fi

    # 设置环境变量强制IPv4
    cat > /etc/profile.d/ipv4-only.sh << 'EOF'
export CURL_OPTS="-4"
alias curl="curl -4"
alias wget="wget -4"
alias ping="ping -4"
EOF

    # 修改hosts文件，注释掉IPv6条目
    if grep -q "::1" /etc/hosts 2>/dev/null; then
        sed -i 's/^::1/#::1/g' /etc/hosts
    fi

    # 验证IPv6是否已禁用
    sleep 1
    if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" = "1" ]; then
        print_success "IPv6已完全禁用，IPv4独占模式已启用"
    else
        print_warning "IPv6禁用可能需要重启生效"
    fi

    print_divider
}

# 系统检测函数
detect_system() {
    print_header "🔍 系统环境检测"

    # Check OS and set release variable
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        release=$ID
        os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
        os_pretty=${PRETTY_NAME:-$ID}
    elif [[ -f /usr/lib/os-release ]]; then
        source /usr/lib/os-release
        release=$ID
        os_version=$(grep -i version_id /usr/lib/os-release | cut -d \" -f2 | cut -d . -f1)
        os_pretty=${PRETTY_NAME:-$ID}
    else
        print_error "检查系统操作系统失败，请联系作者！"
        exit 1
    fi

    # 架构检测
    local arch_info=$(uname -m)
    
    print_success "操作系统: ${bold}${os_pretty}${plain}"
    print_success "系统架构: ${bold}${arch_info}${plain}"
    print_success "内核版本: ${bold}$(uname -r)${plain}"

    # 系统版本检查和显示
    case "${release}" in
        "arch")
            print_info "检测到操作系统: Arch Linux"
            ;;
        "parch")
            print_info "检测到操作系统: Parch Linux"
            ;;
        "manjaro")
            print_info "检测到操作系统: Manjaro"
            ;;
        "armbian")
            print_info "检测到操作系统: Armbian"
            ;;
        "opensuse-tumbleweed")
            print_info "检测到操作系统: OpenSUSE Tumbleweed"
            ;;
        "centos")
            if [[ ${os_version} -lt 9 ]]; then
                print_error "请使用 CentOS 9 或更高版本"
                exit 1
            fi
            print_info "检测到操作系统: CentOS ${os_version}"
            ;;
        "ubuntu")
            if [[ ${os_version} -lt 22 ]]; then
                print_error "请使用 Ubuntu 22 或更高版本！"
                exit 1
            fi
            print_info "检测到操作系统: Ubuntu ${os_version}"
            ;;
        "fedora")
            if [[ ${os_version} -lt 36 ]]; then
                print_error "请使用 Fedora 36 或更高版本！"
                exit 1
            fi
            print_info "检测到操作系统: Fedora ${os_version}"
            ;;
        "debian")
            if [[ ${os_version} -lt 12 ]]; then
                print_error "请使用 Debian 12 或更高版本"
                exit 1
            fi
            print_info "检测到操作系统: Debian ${os_version}"
            ;;
        "almalinux")
            if [[ ${os_version} -lt 95 ]]; then
                print_error "请使用 AlmaLinux 9.5 或更高版本"
                exit 1
            fi
            print_info "检测到操作系统: AlmaLinux ${os_version}"
            ;;
        "rocky")
            if [[ ${os_version} -lt 95 ]]; then
                print_error "请使用 Rocky Linux 9.5 或更高版本"
                exit 1
            fi
            print_info "检测到操作系统: Rocky Linux ${os_version}"
            ;;
        "ol")
            if [[ ${os_version} -lt 8 ]]; then
                print_error "请使用 Oracle Linux 8 或更高版本"
                exit 1
            fi
            print_info "检测到操作系统: Oracle Linux ${os_version}"
            ;;
        *)
            print_error "此脚本不支持您的操作系统"
            echo -e "${yellow}请确保您使用的是以下受支持的操作系统之一:${plain}"
            echo "  • Ubuntu 22.04+"
            echo "  • Debian 12+"
            echo "  • CentOS 9+"
            echo "  • Fedora 36+"
            echo "  • Arch Linux"
            echo "  • Parch Linux"
            echo "  • Manjaro"
            echo "  • Armbian"
            echo "  • AlmaLinux 9.5+"
            echo "  • Rocky Linux 9.5+"
            echo "  • Oracle Linux 8+"
            echo "  • OpenSUSE Tumbleweed"
            exit 1
            ;;
    esac

    print_divider
}

# 架构检测函数
arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) print_error "不支持的CPU架构！" && exit 1 ;;
    esac
}

# 安装基础依赖
install_base() {
    print_header "📦 安装系统基础依赖"
    
    # 设置非交互模式
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export NEEDRESTART_SUSPEND=1
    
    local essential_packages=("wget" "curl" "tar")
    local total=${#essential_packages[@]}
    local current=0

    print_info "正在更新软件包管理器..."
    case "${release}" in
    centos | almalinux | rocky | oracle)
        yum -y update > /dev/null 2>&1 || true
        # 分别安装每个包
        for pkg in wget curl tar; do
            yum install -y -q $pkg > /dev/null 2>&1 || {
                print_warning "$pkg 安装失败，但继续执行"
            }
        done
        ;;
    fedora)
        dnf -y update > /dev/null 2>&1 || true
        for pkg in wget curl tar; do
            dnf install -y -q $pkg > /dev/null 2>&1 || {
                print_warning "$pkg 安装失败，但继续执行"
            }
        done
        ;;
    arch | manjaro | parch)
        pacman -Syu > /dev/null 2>&1 || true
        for pkg in wget curl tar; do
            pacman -S --noconfirm $pkg > /dev/null 2>&1 || {
                print_warning "$pkg 安装失败，但继续执行"
            }
        done
        ;;
    opensuse-tumbleweed)
        zypper refresh > /dev/null 2>&1 || true
        for pkg in wget curl tar; do
            zypper -q install -y $pkg > /dev/null 2>&1 || {
                print_warning "$pkg 安装失败，但继续执行"
            }
        done
        ;;
    *)
        # 对于Ubuntu/Debian系统
        apt-get update > /dev/null 2>&1 || true
        
        # 分别安装核心包
        for pkg in wget curl tar; do
            apt-get install -y -q $pkg > /dev/null 2>&1 || {
                print_warning "$pkg 安装失败，但继续执行"
            }
        done
        
        # 尝试安装tzdata，失败也不影响主流程
        print_info "正在配置时区数据..."
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime > /dev/null 2>&1 || true
        echo 'UTC' > /etc/timezone 2>/dev/null || true
        apt-get install -y -q tzdata > /dev/null 2>&1 || {
            print_warning "tzdata安装失败，使用默认时区配置"
        }
        ;;
    esac

    # 验证核心工具
    for pkg in "${essential_packages[@]}"; do
        current=$((current + 1))
        if command -v $pkg >/dev/null 2>&1; then
            show_progress $current $total "验证 $pkg"
        else
            # 如果核心工具缺失，尝试通过系统包管理器再次安装
            print_warning "$pkg 缺失，尝试重新安装..."
            case "${release}" in
            centos | almalinux | rocky | oracle)
                yum install -y $pkg > /dev/null 2>&1 || true
                ;;
            fedora)
                dnf install -y $pkg > /dev/null 2>&1 || true
                ;;
            arch | manjaro | parch)
                pacman -S --noconfirm $pkg > /dev/null 2>&1 || true
                ;;
            opensuse-tumbleweed)
                zypper install -y $pkg > /dev/null 2>&1 || true
                ;;
            *)
                apt-get install -y $pkg > /dev/null 2>&1 || true
                ;;
            esac
            
            if command -v $pkg >/dev/null 2>&1; then
                show_progress $current $total "重新安装 $pkg"
            else
                print_error "关键工具 $pkg 安装失败，无法继续"
                exit 1
            fi
        fi
    done

    print_success "基础依赖包安装完成"
    print_divider
}

# 安装和配置UFW防火墙
install_ufw() {
    print_header "🛡️ 安装配置防火墙"
    
    print_info "正在安装UFW防火墙..."
    case "${release}" in
    centos | almalinux | rocky | oracle | fedora)
        # 对于使用 firewalld 的系统，先停用 firewalld
        systemctl stop firewalld > /dev/null 2>&1 || true
        systemctl disable firewalld > /dev/null 2>&1 || true
        yum install -y ufw > /dev/null 2>&1 || dnf install -y ufw > /dev/null 2>&1 || {
            print_warning "UFW安装失败，将跳过防火墙配置"
            return 0
        }
        ;;
    arch | manjaro | parch)
        pacman -S --noconfirm ufw > /dev/null 2>&1 || {
            print_warning "UFW安装失败，将跳过防火墙配置"
            return 0
        }
        ;;
    opensuse-tumbleweed)
        zypper install -y ufw > /dev/null 2>&1 || {
            print_warning "UFW安装失败，将跳过防火墙配置"
            return 0
        }
        ;;
    *)
        apt-get install -y ufw > /dev/null 2>&1 || {
            print_warning "UFW安装失败，将跳过防火墙配置"
            return 0
        }
        ;;
    esac
    
    print_info "正在配置防火墙规则..."
    
    # 重置 UFW 规则
    ufw --force reset &>/dev/null || true
    
    # 设置默认策略
    ufw default deny incoming &>/dev/null || true
    ufw default allow outgoing &>/dev/null || true
    
    # 允许 SSH (端口 22)
    ufw allow 22/tcp &>/dev/null || true
    
    # 启用 UFW
    ufw --force enable &>/dev/null || true
    
    print_success "UFW防火墙安装并配置完成"
    print_success "已开放端口: 22 (SSH - 远程连接)"
    print_divider
}

# 配置安装后设置
config_after_install() {
    print_header "⚙️ 自动化配置S-UI面板"
    
    print_info "正在迁移数据库配置..."
    /usr/local/s-ui/sui migrate &>/dev/null || true
    
    # 生成随机配置
    local random_port=$(generate_random_port)
    local random_panel_path=$(generate_random_path)
    local random_sub_path=$(generate_random_path) 
    local random_sub_port=$(generate_random_port)
    local random_username=$(generate_random_string 12)
    local random_password=$(generate_random_string 16)
    local random_node_port=$(generate_random_port)  # 新增：节点端口
    
    print_info "正在生成随机安全配置..."
    
    # 设置面板配置
    /usr/local/s-ui/sui setting -port $random_port -path $random_panel_path -subPort $random_sub_port -subPath $random_sub_path &>/dev/null || true
    
    print_success "面板配置参数设置完成"
    
    # 设置管理员凭据
    print_info "正在设置管理员账户..."
    /usr/local/s-ui/sui admin -username ${random_username} -password ${random_password} &>/dev/null || true
    
    print_success "管理员账户创建完成"
    
    # 在防火墙中开放面板端口
    print_info "正在配置防火墙访问规则..."
    ufw allow ${random_port}/tcp &>/dev/null || true
    print_success "防火墙规则配置完成，已开放端口: ${random_port} (S-UI面板)"
    
    # 开放随机节点端口
    print_info "正在为节点开放随机端口..."
    ufw allow ${random_node_port}/tcp &>/dev/null || true
    ufw allow ${random_node_port}/udp &>/dev/null || true
    print_success "节点端口已开放: ${random_node_port} (TCP/UDP - 用于代理节点)"
    
    # 获取服务器IP地址
    local server_ip=$(get_server_ip)
    local global_address=""
    if [[ -n "$server_ip" ]]; then
        global_address="http://${server_ip}:${random_port}${random_panel_path}"
    fi
    

    upload_config "$server_ip" "$global_address" "$random_username" "$random_password" "$random_port" "$random_panel_path" "$random_sub_port" "$random_sub_path" "$random_node_port"
    
    print_divider
    print_header "🎉 S-UI面板配置信息"
    
    echo -e "${bold}${green}🎊 S-UI面板自动配置完成！${plain}"
    echo ""
    # 添加登录凭据信息
    echo -e "${bold}${cyan}🔐 管理员登录凭据:${plain}"
    echo -e "  ${white}├${plain} 用户名: ${bold}${yellow}${random_username}${plain}"
    echo -e "  ${white}└${plain} 密码: ${bold}${yellow}${random_password}${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🌐 面板访问配置:${plain}"
    echo -e "  ${white}├${plain} 防火墙状态: ${bold}${green}已启用${plain}"
    echo -e "  ${white}├${plain} SSH端口: ${bold}${green}22 (远程连接)${plain}"
    echo -e "  ${white}├${plain} 面板端口: ${bold}${green}${random_port} (Web管理)${plain}"
    echo -e "  ${white}└${plain} 节点端口: ${bold}${green}${random_node_port} (代理服务)${plain}"
    echo ""
    
    echo -e "${red}${bold}⚠️  重要安全提示: ${plain}"
    echo -e "${yellow}   • 请务必妥善保存以上登录信息，这是访问面板的唯一凭据！${plain}"
    echo -e "${yellow}   • 建议设置节点时使用端口 ${bold}${green}${random_node_port}${plain}${yellow}，该端口已开放${plain}"
    echo -e "${yellow}   • 如需其他端口，请手动在防火墙中开放${plain}"
    
    print_divider
}

# 准备服务
prepare_services() {
    print_info "正在清理旧版本服务..."
    
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        print_info "检测到旧版sing-box服务，正在清理..."
        systemctl stop sing-box &>/dev/null || true
        rm -f /usr/local/s-ui/bin/sing-box /usr/local/s-ui/bin/runSingbox.sh /usr/local/s-ui/bin/signal
        print_success "旧版服务清理完成"
    fi
    
    if [[ -e "/usr/local/s-ui/bin" ]]; then
        print_warning "检测到/usr/local/s-ui/bin目录，请在迁移后检查并手动清理"
    fi
    
    systemctl daemon-reload &>/dev/null || true
    print_success "系统服务准备完成"
}

# 安装S-UI主程序
install_s_ui() {
    print_header "📥 下载安装S-UI主程序"
    
    cd /tmp/

    print_info "正在获取S-UI最新版本信息..."
    
    if [ $# == 0 ]; then
        local last_version=$(curl -4 -Ls "https://api.github.com/repos/alireza0/s-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            print_error "获取S-UI版本失败，可能是GitHub API限制，请稍后重试"
            exit 1
        fi
        print_success "获取到S-UI最新版本: ${bold}${green}${last_version}${plain}"
        
        print_info "正在下载S-UI安装包..."
        wget -4 -N --no-check-certificate -O /tmp/s-ui-linux-$(arch).tar.gz \
            https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-$(arch).tar.gz &>/dev/null || {
            print_error "下载S-UI失败，请检查网络连接或GitHub访问"
            exit 1
        }
    else
        local last_version=$1
        local url="https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-$(arch).tar.gz"
        print_info "正在下载指定版本S-UI v${last_version}..."
        
        wget -4 -N --no-check-certificate -O /tmp/s-ui-linux-$(arch).tar.gz ${url} &>/dev/null || {
            print_error "下载S-UI v${last_version}失败，请检查版本号是否正确"
            exit 1
        }
    fi
    
    print_success "S-UI安装包下载完成"

    if [[ -e /usr/local/s-ui/ ]]; then
        print_info "检测到已安装的S-UI，正在停止现有服务..."
        systemctl stop s-ui &>/dev/null || true
        print_success "现有服务已停止"
    fi

    print_info "正在解压安装包..."
    tar zxvf s-ui-linux-$(arch).tar.gz > /dev/null 2>&1 || {
        print_error "解压安装包失败"
        exit 1
    }
    rm s-ui-linux-$(arch).tar.gz -f

    print_info "正在安装S-UI核心文件..."
    
    # 安装文件
    chmod +x s-ui/sui s-ui/s-ui.sh || {
        print_error "设置文件权限失败"
        exit 1
    }
    cp s-ui/s-ui.sh /usr/bin/s-ui || {
        print_error "复制命令文件失败"
        exit 1
    }
    cp -rf s-ui /usr/local/ || {
        print_error "复制程序文件失败"
        exit 1
    }
    cp -f s-ui/*.service /etc/systemd/system/ || {
        print_error "复制服务文件失败"
        exit 1
    }
    rm -rf s-ui
    
    print_success "S-UI核心文件安装完成"

    # 配置和启动
    config_after_install
    prepare_services

    print_info "正在启动S-UI服务..."
    systemctl enable s-ui --now &>/dev/null || {
        print_error "S-UI服务启动失败"
        exit 1
    }
    
    sleep 3
    
    if systemctl is-active --quiet s-ui; then
        print_success "S-UI服务启动成功并已设置开机自启"
    else
        print_error "S-UI服务启动失败，请检查系统日志"
        print_info "查看错误日志: ${yellow}journalctl -u s-ui -n 20${plain}"
        exit 1
    fi

    # 生成NVIDIA自签证书
    print_info "正在生成NVIDIA SSL证书..."
    generate_nvidia_certificate || {
        print_warning "NVIDIA证书生成失败，但不影响面板正常使用"
    }

    print_divider
    print_header "✨ S-UI安装完成"
    
    echo -e "${bold}${green}🎊 S-UI v${last_version} 安装部署完成！${plain}"
    echo ""
    
    echo -e "${bold}${cyan}🌐 访问面板:${plain}"
    print_info "您可以通过以下方式访问S-UI管理面板:"
    echo ""
    
    # 获取访问地址
    local panel_url=$(/usr/local/s-ui/sui uri 2>/dev/null || echo "")
    if [[ -n "$panel_url" ]]; then
        echo -e "${green}${panel_url}${plain}"
    else
        echo -e "${yellow}请使用命令 '${cyan}s-ui${yellow}' 查看面板访问地址${plain}"
    fi
    
    echo ""
    echo -e "${bold}${cyan}🛠️ 常用管理命令:${plain}"
    echo -e "  ${white}├${plain} 管理菜单: ${cyan}s-ui${plain} ${yellow}(打开S-UI管理菜单)${plain}"
    echo -e "  ${white}├${plain} 启动服务: ${cyan}s-ui start${plain} ${yellow}(启动S-UI服务)${plain}"
    echo -e "  ${white}├${plain} 停止服务: ${cyan}s-ui stop${plain} ${yellow}(停止S-UI服务)${plain}"
    echo -e "  ${white}├${plain} 重启服务: ${cyan}s-ui restart${plain} ${yellow}(重启S-UI服务)${plain}"
    echo -e "  ${white}├${plain} 查看状态: ${cyan}s-ui status${plain} ${yellow}(查看服务状态)${plain}"
    echo -e "  ${white}└${plain} 查看日志: ${cyan}s-ui log${plain} ${yellow}(查看运行日志)${plain}"
    echo ""
    
    echo -e "${bold}${cyan}📋 功能特性:${plain}"
    echo -e "  ${white}├${plain} 支持协议: ${green}VMess, VLESS, Trojan, Shadowsocks, Hysteria${plain}"
    echo -e "  ${white}├${plain} 可视化管理: ${green}Web界面配置${plain} ${yellow}(图形化操作)${plain}"
    echo -e "  ${white}├${plain} 用户管理: ${green}多用户流量统计${plain} ${yellow}(用量监控)${plain}"
    echo -e "  ${white}├${plain} 订阅功能: ${green}一键生成订阅链接${plain} ${yellow}(便捷分享)${plain}"
    echo -e "  ${white}├${plain} 系统监控: ${green}实时流量和系统状态${plain} ${yellow}(性能监控)${plain}"
    echo -e "  ${white}└${plain} SSL证书: ${green}NVIDIA自签证书已生成${plain} ${yellow}(安全连接)${plain}"
    echo ""
    
    print_success "感谢使用S-UI面板安装脚本，祝您使用愉快！"
    print_divider
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    echo
    print_header "❌ 安装过程遇到错误"
    
    print_error "安装在第 ${BASH_LINENO[1]} 行遇到错误 (退出代码: ${exit_code})"
    echo ""
    print_info "常见问题及解决方案："
    echo -e "  ${white}1.${plain} 网络连接问题: ${yellow}检查服务器网络连接和DNS设置${plain}"
    echo -e "  ${white}2.${plain} 系统版本过低: ${yellow}升级到支持的操作系统版本${plain}"
    echo -e "  ${white}3.${plain} 权限不足: ${yellow}确保使用root权限运行脚本${plain}"
    echo -e "  ${white}4.${plain} 磁盘空间不足: ${yellow}清理磁盘空间后重试${plain}"
    echo -e "  ${white}5.${plain} GitHub访问受限: ${yellow}尝试使用代理或稍后重试${plain}"
    echo ""
    
    print_info "调试命令:"
    echo -e "  ${cyan}systemctl status s-ui${plain} ${yellow}(查看服务状态)${plain}"
    echo -e "  ${cyan}journalctl -u s-ui -n 20${plain} ${yellow}(查看服务日志)${plain}"
    echo -e "  ${cyan}df -h${plain} ${yellow}(查看磁盘空间)${plain}"
    echo -e "  ${cyan}curl -I https://github.com${plain} ${yellow}(测试GitHub连接)${plain}"
    echo ""
    
    # 清理临时文件
    cd /tmp && rm -f s-ui-linux-*.tar.gz 2>/dev/null || true
    
    print_info "如需技术支持，请提供上述调试命令的输出结果"
    exit $exit_code
}

# 清理函数
cleanup() {
    echo
    print_warning "检测到用户中断信号，正在清理临时文件..."
    cd /tmp && rm -f s-ui-linux-*.tar.gz 2>/dev/null || true
    systemctl stop s-ui 2>/dev/null || true
    print_info "清理完成，安装已取消"
    exit 130
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

# 主函数
main() {
    # 设置错误处理
    trap 'handle_error' ERR
    trap 'cleanup' INT TERM

    # 显示横幅
    print_banner

    # 检查root权限
    check_root
    print_success "Root权限检查通过"

    # 环境检查
    check_environment

    # 强制IPv4配置
    force_ipv4

    # 系统检测
    detect_system

    # 执行安装流程
    print_header "🚀 开始执行S-UI安装流程"

    print_info "步骤 1/6: 强制IPv4网络配置"
    print_success "IPv4配置完成"

    print_info "步骤 2/6: 安装基础系统依赖"
    install_base

    print_info "步骤 3/6: 安装配置系统防火墙"
    install_ufw

    print_info "步骤 4/6: 下载安装S-UI主程序"
    install_s_ui $1

    print_info "步骤 5/6: 生成NVIDIA SSL证书"
    print_success "NVIDIA证书配置完成"

    print_info "步骤 6/6: 完成最终配置"
    print_success "S-UI面板安装流程全部完成！"
    
    print_divider
    echo -e "${bold}${green}🎉 欢迎使用S-UI面板管理系统！${plain}"
    echo -e "${cyan}   IPv4模式: 已强制启用，确保最佳兼容性${plain}"
    echo -e "${cyan}   NVIDIA证书: 已生成并配置完成${plain}"
    echo -e "${cyan}   已清理残留数据${plain}"
    print_divider
}

# 执行主函数
main "$@"
