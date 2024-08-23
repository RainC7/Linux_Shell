#!/bin/bash

# 检测系统类型
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

# 安装依赖包
install_dependencies() {
    echo "安装依赖包..."
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
            echo "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 检查并更新 OpenSSL
check_and_update_openssl() {
    echo "检查 OpenSSL 版本..."
    current_openssl_version=$(openssl version | awk '{print $2}')
    required_version="1.1.1"  # 设置最低要求版本

    echo "当前 OpenSSL 版本: $current_openssl_version"
    echo "最低要求版本: $required_version"

    if [[ "$(printf '%s\n' "$required_version" "$current_openssl_version" | sort -V | head -n1)" == "$required_version" ]]; then
        echo "当前 OpenSSL 版本满足最低要求。"
        read -p "是否仍要安装新版本的 OpenSSL? (y/n): " install_new_openssl
    else
        echo "当前 OpenSSL 版本不满足最低要求。"
        read -p "是否要安装新版本的 OpenSSL? (y/n): " install_new_openssl
    fi

    if [ "$install_new_openssl" != "y" ]; then
        echo "保持当前 OpenSSL 版本。"
        return
    fi

    echo "OpenSSL 版本选择："
    echo "1) 最新版本 (3.3.1)"
    echo "2) 旧版本 (1.1.1i)"
    echo "3) 自定义版本"
    read -p "请选择要安装的 OpenSSL 版本 (1/2/3): " openssl_choice

    case $openssl_choice in
        1)
            openssl_version="3.3.1"
            ;;
        2)
            openssl_version="1.1.1i"
            ;;
        3)
            read -p "请输入要安装的 OpenSSL 版本 (例如: 3.3.1): " openssl_version
            ;;
        *)
            echo "无效的选择，使用最新版本 3.3.1"
            openssl_version="3.3.1"
            ;;
    esac

    echo "准备安装 OpenSSL $openssl_version ..."

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

    # 下载并解压 OpenSSL
    cd /usr/local/src
    wget https://www.openssl.org/source/openssl-$openssl_version.tar.gz
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
    cd /usr/local/src
    rm -rf openssl-$openssl_version openssl-$openssl_version.tar.gz

    # 验证安装
    new_openssl_version=$(openssl version | awk '{print $2}')
    echo "OpenSSL 已更新到新版本: $new_openssl_version"
}


echo "Python 一键安装脚本"
echo "By Lynn"
echo "Version 2408220145"
echo "系统版本：$OS"
# 提示用户输入Python版本号
read -p "请输入要安装的Python版本号（例如3.12.5）: " version

# 检查输入的版本号是否合法
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "无效的版本号格式！请使用X.Y.Z格式的版本号。"
  exit 1
fi

# 设置Python安装目录
install_dir="/usr/local/python$version"

# 设置Python安装包下载地址
python_url="https://registry.npmmirror.com/-/binary/python/$version/Python-$version.tgz"

# 安装依赖包
install_dependencies

# 检查并更新 OpenSSL
check_and_update_openssl

# 下载Python源码包
echo "正在下载Python $version ..."
if ! wget --no-check-certificate "$python_url" -P /tmp/; then
  echo "下载Python安装包失败！"
  exit 1
fi

# 解压安装包
echo "解压安装包..."
if ! tar -xzvf "/tmp/Python-$version.tgz" -C /tmp/; then
  echo "解压Python安装包失败！"
  exit 1
fi

# 进入解压后的目录
cd "/tmp/Python-$version"

# 修改 Modules/Setup 文件
echo "修改 Modules/Setup 文件..."

# 询问用户是否要静态链接 OpenSSL
read -p "是否要静态链接 OpenSSL? (y/n): " static_ssl

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
echo "配置Python..."
if ! ./configure --prefix="$install_dir" --enable-optimizations --with-ensurepip=install --with-openssl=/usr/local/openssl; then
  echo "配置Python失败！"
  exit 1
fi

# 编译Python
echo "编译Python..."
if ! make -j "$(nproc)"; then
  echo "编译Python失败！"
  exit 1
fi

# 安装Python
echo "安装Python..."
if ! sudo make altinstall; then
  echo "安装Python失败！"
  exit 1
fi

# 清理临时文件
rm -rf "/tmp/Python-$version" "/tmp/Python-$version.tgz"

echo "Python $version 已成功安装到 $install_dir 目录。"

# 创建快捷方式到/usr/local/bin
echo "创建Python $version 快捷方式到/usr/local/bin..."
if [[ $version == "2."* ]]; then
  link_name="python2"
else
  link_name="python3"
fi

if ! sudo ln -s "$install_dir/bin/$link_name" "/usr/local/bin/python$version"; then
  echo "创建快捷方式失败！"
  exit 1
fi

echo "快捷方式已创建。"

# 验证SSL支持
echo "验证SSL支持..."
if "$install_dir/bin/$link_name" -c "import ssl; print(ssl.OPENSSL_VERSION)"; then
    echo "SSL 支持已成功启用"
else
    echo "SSL 支持验证失败，请检查安装"
    exit 1
fi

echo "安装完成。"
