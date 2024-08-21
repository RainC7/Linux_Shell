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

# 提示用户输入Python版本号
read -p "请输入要安装的Python版本号（例如3.12.5）: " version

# 检查输入的版本号是否合法（这里简单地检查是否有三个点号分隔的数字）
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

# 下载Python二进制安装包
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

# 配置、编译和安装Python
echo "配置Python..."
if ! ./configure --prefix="$install_dir" --enable-optimizations --with-ensurepip=install --with-ssl; then
  echo "配置Python失败！"
  exit 1
fi

echo "编译Python..."
if ! make -j "$(nproc)"; then
  echo "编译Python失败！"
  exit 1
fi

echo "安装Python..."
if ! sudo make altinstall; then
  echo "安装Python失败！"
  exit 1
fi

# 清理临时文件
rm -rf "/tmp/Python-$version" "/tmp/Python-$version.tgz"

echo "Python $version 已成功安装到 $install_dir 目录。"

# 创建快捷方式到/usr/local/bin，将python版本映射到python3
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
"$install_dir/bin/$link_name" -c "import ssl; print(ssl.OPENSSL_VERSION)"

echo "安装完成。"
