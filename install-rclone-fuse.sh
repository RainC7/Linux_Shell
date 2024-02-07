#!/bin/bash

# 定义安装函数
install_fuse3() {
    case $1 in
        apt)
            sudo apt update && sudo apt install -y fuse3
            ;;
        yum)
            sudo yum install -y fuse3
            ;;
        dnf)
            sudo dnf install -y fuse3
            ;;
        zypper)
            sudo zypper install -y fuse3
            ;;
        *)
            echo "不支持的包管理器: $1"
            exit 1
            ;;
    esac
}

# 安装rclone的函数
install_rclone() {
    curl https://rclone.org/install.sh | sudo bash
}

# 自动检测发行版并选择合适的包管理器
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=$ID
elif type lsb_release >/dev/null 2>&1; then
    DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
else
    echo "无法确定发行版类型。"
    exit 1
fi

case $DISTRO in
    ubuntu|debian)
        PKG_MANAGER=apt
        ;;
    centos|rhel|fedora)
        # CentOS 8及之前版本默认使用yum，CentOS 8及Fedora较新版本使用dnf
        if type dnf >/dev/null 2>&1; then
            PKG_MANAGER=dnf
        else
            PKG_MANAGER=yum
        fi
        ;;
    opensuse*|sles)
        PKG_MANAGER=zypper
        ;;
    *)
        echo "不支持的Linux发行版: $DISTRO"
        exit 1
        ;;
esac

# 安装fuse3和rclone
install_fuse3 $PKG_MANAGER
install_rclone

# 显示安装版本
echo "安装的rclone版本："
rclone --version
echo "安装的fuse3版本："
fusermount3 -V

echo "rclone 和 fuse3 安装完成！"
