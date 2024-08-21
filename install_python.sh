#!/bin/bash

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

# 安装依赖包，包括SSL开发库
echo "安装依赖包..."
sudo apt-get update
sudo apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

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

# 配置、编译和安装Python（包含SSL支持）
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

# 创建快捷方式到/usr/local/bin
echo "创建Python $version 快捷方式到/usr/local/bin..."
if [[ $version == 2.* ]]; then
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
