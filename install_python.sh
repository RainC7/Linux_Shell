#!/bin/bash

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 打印分割线
print_separator() {
    print_color $CYAN "----------------------------------------"
}

# 检查网络连接和延迟
check_network_and_latency() {
    local host=$1
    local count=1
    local timeout=1
    
    ping_output=$(ping -c $count -W $timeout $host 2>&1)
    if [ $? -eq 0 ]; then
        latency=$(echo "$ping_output" | awk -F'/' 'END {print $5}')
        latency=${latency%.*}  # 移除小数部分
        echo "$latency"
    else
        echo "-1"
    fi
}

# 检查是否在中国大陆
check_if_in_china() {
    local in_china=false
    local user_choice=""

    # 尝试使用 ipapi.co 检测
    local country_code=$(curl -s --connect-timeout 5 https://ipapi.co/country_code)
    if [ "$country_code" == "CN" ]; then
        in_china=true
        print_color $YELLOW "检测到您位于中国大陆。"
    elif [ -z "$country_code" ]; then
        # ipapi.co 无法连通，进行 GitHub 和百度的连通性测试
        local github_latency=$(check_network_and_latency github.com)
        local baidu_latency=$(check_network_and_latency www.baidu.com)

        if [ $github_latency -eq -1 ] && [ $baidu_latency -ne -1 ] && [ $baidu_latency -lt 100 ]; then
            in_china=true
            print_color $YELLOW "当前服务器无法连接至 GitHub，推荐开启中国大陆加速模式。"
        elif [ $github_latency -eq -1 ]; then
            print_color $RED "当前可能无法连接到 GitHub，请检查 GitHub 状态。"
        elif [ $github_latency -ne -1 ] && [ $baidu_latency -ne -1 ] && [ $baidu_latency -lt 100 ]; then
            in_china=true
            print_color $YELLOW "检测到您可能位于中国大陆。当前服务器可以连接至 GitHub。"
        else
            print_color $GREEN "检测到您可能不在中国大陆。"
        fi
    else
        print_color $GREEN "检测到您不在中国大陆。"
    fi

    print_separator
    read -p "$(print_color $PURPLE '是否启用中国大陆模式？(y/n): ')" user_choice

    if [[ $user_choice == "y" || $user_choice == "Y" ]]; then
        return 0  # 启用中国大陆模式
    else
        return 1  # 不启用中国大陆模式
    fi
}

# 获取系统信息
get_system_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo -e "${GREEN}$OS${NC} ${YELLOW}$VER${NC}"
}

# 获取Python版本
get_python_version() {
    python_version=$(python3 --version 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}未安装${NC}"
    else
        echo -e "${GREEN}$python_version${NC}"
    fi
}

# 获取OpenSSL版本
get_openssl_version() {
    openssl_version=$(openssl version 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}未安装${NC}"
    else
        echo -e "${GREEN}$openssl_version${NC}"
    fi
}

# 检查SSL连接状态
check_ssl_connection() {
    if python3 -c "import ssl; ssl.create_default_context().wrap_socket(ssl.socket())" 2>/dev/null; then
        echo -e "${GREEN}正常${NC}"
    else
        echo -e "${RED}异常${NC}"
    fi
}

# 下载文件的函数，带有重试和备用源
download_with_retry() {
    local url=$1
    local output=$2
    local backup_url=$3
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if wget --no-check-certificate "$url" -O "$output"; then
            print_color $GREEN "下载成功: $output"
            return 0
        else
            retry_count=$((retry_count+1))
            print_color $YELLOW "下载失败，尝试重试 ($retry_count/$max_retries)"
            sleep 5
        fi
    done

    if [ -n "$backup_url" ]; then
        print_color $YELLOW "尝试使用备用下载源"
        if wget --no-check-certificate "$backup_url" -O "$output"; then
            print_color $GREEN "从备用源下载成功: $output"
            return 0
        fi
    fi

    print_color $RED "下载失败: $output"
    return 1
}

# 安装依赖包
install_dependencies() {
    print_color $YELLOW "安装依赖包..."
    case $OS in
        "Ubuntu"|"Debian")
            sudo apt-get update
            sudo apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux"|"Fedora")
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel expat-devel
            if [ "$VER" == "8" ]; then
                sudo dnf install -y libffi-devel
            else
                sudo yum install -y libffi-devel
            fi
            ;;
        *)
            print_color $RED "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 检查并更新 OpenSSL
check_and_update_openssl() {
    print_color $YELLOW "检查 OpenSSL 版本..."
    current_openssl_version=$(openssl version | awk '{print $2}')
    required_version="1.1.1"  # 设置最低要求版本

    print_color $GREEN "当前 OpenSSL 版本: $current_openssl_version"
    print_color $GREEN "最低要求版本: $required_version"

    if [[ "$(printf '%s\n' "$required_version" "$current_openssl_version" | sort -V | head -n1)" == "$required_version" ]]; then
        print_color $GREEN "当前 OpenSSL 版本满足最低要求。"
        print_separator
        read -p "$(print_color $PURPLE '是否仍要安装新版本的 OpenSSL? (y/n): ')" install_new_openssl
    else
        print_color $YELLOW "当前 OpenSSL 版本不满足最低要求。"
        print_separator
        read -p "$(print_color $PURPLE '是否要安装新版本的 OpenSSL? (y/n): ')" install_new_openssl
    fi

    if [ "$install_new_openssl" != "y" ]; then
        print_color $GREEN "保持当前 OpenSSL 版本。"
        return
    fi

    print_separator
    print_color $YELLOW "OpenSSL 版本选择："
    print_color $BLUE "1) 最新版本 (3.3.1)"
    print_color $BLUE "2) 旧版本 (1.1.1i)"
    print_color $BLUE "3) 自定义版本"
    print_separator
    read -p "$(print_color $PURPLE '请选择要安装的 OpenSSL 版本 (1/2/3): ')" openssl_choice

    case $openssl_choice in
        1)
            openssl_version="3.3.1"
            ;;
        2)
            openssl_version="1.1.1i"
            ;;
        3)
            read -p "$(print_color $PURPLE '请输入要安装的 OpenSSL 版本 (例如: 3.3.1): ')" openssl_version
            ;;
        *)
            print_color $YELLOW "无效的选择，使用最新版本 3.3.1"
            openssl_version="3.3.1"
            ;;
    esac

    print_color $GREEN "准备安装 OpenSSL $openssl_version ..."

    # 设置下载链接
    if $USE_CHINA_MIRROR; then
        openssl_url="https://kkgithub.com/openssl/openssl/releases/download/openssl-$openssl_version/openssl-$openssl_version.tar.gz"
    else
        openssl_url="https://github.com/openssl/openssl/releases/download/openssl-$openssl_version/openssl-$openssl_version.tar.gz"
    fi

    # 下载 OpenSSL
    if ! download_with_retry "$openssl_url" "/tmp/openssl-$openssl_version.tar.gz"; then
        print_color $RED "下载 OpenSSL 失败，请检查网络连接或稍后重试。"
        return 1
    fi

    # 安装依赖
    case $OS in
        "Ubuntu"|"Debian")
            sudo apt update && sudo apt upgrade
            sudo apt install build-essential checkinstall zlib1g-dev -y
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux"|"Fedora")
            sudo yum group install 'Development Tools'
            sudo yum install perl-core zlib-devel -y
            ;;
    esac

    # 解压和安装 OpenSSL
    cd /tmp
    tar -zxvf openssl-$openssl_version.tar.gz
    cd openssl-$openssl_version

    # 配置、编译和安装
    ./config --prefix=/usr/local/openssl
    make && sudo make install

    # 配置
    sudo mv /usr/bin/openssl /usr/bin/openssl_old
    sudo ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
    sudo ln -s /usr/local/openssl/lib/libssl.so /usr/local/lib64/libssl.so
    sudo ln -s /usr/local/openssl/lib/libcrypto.so /usr/local/lib64/libcrypto.so

    # 配置库文件搜索路径
    echo '/usr/local/openssl/lib' | sudo tee -a /etc/ld.so.conf
    sudo ldconfig -v

    # 清理
    cd /tmp
    rm -rf openssl-$openssl_version openssl-$openssl_version.tar.gz

    # 验证安装
    new_openssl_version=$(openssl version | awk '{print $2}')
    print_color $GREEN "OpenSSL 已更新到新版本: $new_openssl_version"
}

# 设置下载链接
set_download_url() {
    local base_url=$1
    local filename=$2
    
    if $USE_CHINA_MIRROR; then
        echo "https://kkgithub.com/${base_url#https://github.com/}/$filename"
    else
        echo "$base_url/$filename"
    fi
}

# 主要的脚本逻辑
main() {
    # 显示系统信息
    print_color $CYAN "========================================"
    print_color $CYAN "     Python 和 OpenSSL 一键安装脚本"
    print_color $CYAN "             By Lynn"
    print_color $CYAN "       Version v2.0-202408240032"
    print_color $CYAN "========================================"

    print_color $YELLOW "系统信息:"
    echo -e "  操作系统: $(get_system_info)"
    echo -e "  Python版本: $(get_python_version)"
    echo -e "  OpenSSL版本: $(get_openssl_version)"
    echo -e "  SSL连接状态: $(check_ssl_connection)"
    
    # 检查是否使用中国大陆模式
    if check_if_in_china; then
        USE_CHINA_MIRROR=true
        print_color $YELLOW "已启用中国大陆模式，将使用替代下载源。"
    else
        USE_CHINA_MIRROR=false
        print_color $GREEN "未启用中国大陆模式，将使用默认下载源。"
    fi
    echo

    # 显示菜单
    print_separator
    print_color $YELLOW "请选择安装选项:"
    print_color $BLUE "1) 一键安装 Python 与 OpenSSL (使用默认配置)"
    print_color $BLUE "2) 仅安装 OpenSSL"
    print_color $BLUE "3) 自定义安装 Python"
    print_separator
    read -p "$(print_color $PURPLE '请输入选项 (1/2/3): ')" install_option

    case $install_option in
        1)
            print_color $GREEN "您选择了一键安装 Python 与 OpenSSL (使用默认配置)"
            # 设置默认值
            openssl_version="3.3.1"
            install_new_openssl="y"
            static_ssl="n"
            ;;
        2)
            print_color $GREEN "您选择了仅安装 OpenSSL"
            ;;
        3)
            print_color $GREEN "您选择了自定义安装 Python"
            ;;
        *)
            print_color $RED "无效的选项，退出程序"
            exit 1
            ;;
    esac

    # 根据用户选择执行相应的安装流程
    case $install_option in
        1|3)
            install_dependencies
            check_and_update_openssl
            # 提示用户输入Python版本号
            print_separator
            read -p "$(print_color $PURPLE '请输入要安装的Python版本号（例如3.12.5）: ')" version

            # 检查输入的版本号是否合法
            if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                print_color $RED "无效的版本号格式！请使用X.Y.Z格式的版本号。"
                exit 1
            fi

            # 设置Python安装目录
            install_dir="/usr/local/python$version"

            # 设置Python安装包下载地址
            python_url=$(set_download_url "https://github.com/python/cpython/archive" "v$version.tar.gz")
            python_backup_url="https://www.python.org/ftp/python/$version/Python-$version.tgz"

            # 下载Python源码包
            print_color $YELLOW "正在下载Python $version ..."
            if ! download_with_retry "$python_url" "/tmp/Python-$version.tgz" "$python_backup_url"; then
                print_color $RED "无法下载Python安装包。请检查您的网络连接或稍后重试。"
                exit 1
            fi

            # 解压安装包
            print_color $YELLOW "解压安装包..."
            if ! tar -xzvf "/tmp/Python-$version.tgz" -C /tmp/; then
                print_color $RED "解压Python安装包失败！"
                exit 1
            fi

            # 进入解压后的目录
            cd "/tmp/Python-$version"

            # 修改 Modules/Setup 文件
            print_color $YELLOW "修改 Modules/Setup 文件..."

            if [ "$install_option" == "3" ]; then
                print_separator
                read -p "$(print_color $PURPLE '是否要静态链接 OpenSSL? (y/n): ')" static_ssl
            fi

            if [ "$static_ssl" = "y" ]; then
                # 静态链接 OpenSSL
                sed -i 's/^#_ssl/_ssl/g' Modules/Setup
                sed -i 's/^#_hashlib/_hashlib/g' Modules/Setup
                sed -i 's/^#\(.*\)-l:libssl.a/\1-l:libssl.a/g' Modules/Setup
                sed -i 's/^#\(.*\)-l:libcrypto.a/\1-l:libcrypto.a/g' Modules/Setup
            else
                # 动态链接 OpenSSL（默认选项）
                sed -i 's/^#_ssl/_ssl/g' Modules/Setup
                sed -i 's/^#_hashlib/_hashlib/g' Modules/Setup
                sed -i 's/^#\(.*\)$(OPENSSL_LIBS)/\1$(OPENSSL_LIBS)/g' Modules/Setup
            fi

            # 配置Python
            print_color $YELLOW "配置Python..."
            if ! ./configure --prefix="$install_dir" --enable-optimizations --with-ensurepip=install --with-openssl=/usr/local/openssl; then
                print_color $RED "配置Python失败！"
                exit 1
            fi

            # 编译Python
            print_color $YELLOW "编译Python..."
            if ! make -j "$(nproc)"; then
                print_color $RED "编译Python失败！"
                exit 1
            fi

            # 安装Python
            print_color $YELLOW "安装Python..."
            if ! sudo make altinstall; then
                print_color $RED "安装Python失败！"
                exit 1
            fi

            # 清理临时文件
            rm -rf "/tmp/Python-$version" "/tmp/Python-$version.tgz"

            print_color $GREEN "Python $version 已成功安装到 $install_dir 目录。"

            # 创建快捷方式到/usr/local/bin
            print_color $YELLOW "创建Python $version 快捷方式到/usr/local/bin..."
            if [[ $version == 2.* ]]; then
                link_name="python2"
            else
                link_name="python3"
            fi

            if ! sudo ln -s "$install_dir/bin/$link_name" "/usr/local/bin/python$version"; then
                print_color $RED "创建快捷方式失败！"
                exit 1
            fi

            print_color $GREEN "快捷方式已创建。"

            # 验证SSL支持
            print_color $YELLOW "验证SSL支持..."
            if "$install_dir/bin/$link_name" -c "import ssl; print(ssl.OPENSSL_VERSION)"; then
                print_color $GREEN "SSL 支持已成功启用"
            else
                print_color $RED "SSL 支持验证失败，请检查安装"
                exit 1
            fi

            print_color $GREEN "安装完成。"
            ;;
        2)
            check_and_update_openssl
            print_color $GREEN "OpenSSL 安装完成。"
            ;;
    esac
}

# 执行主函数
main