#!/bin/bash

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
if ! ./configure --prefix="$install_dir"; then
  echo "配置Python失败！"
  exit 1
fi

echo "编译Python..."
if ! make; then
  echo "编译Python失败！"
  exit 1
fi

echo "安装Python..."
if ! sudo make install; then
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
