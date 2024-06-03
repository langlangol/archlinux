#!/bin/bash

# Arch Linux 安装脚本

set -e

# 确认已经在UEFI模式下启动
if [ ! -d /sys/firmware/efi ]; then
    echo "请在UEFI模式下启动此安装脚本。"
    exit 1
fi

# 设置键盘布局（可根据需要修改）
loadkeys us

# 更新系统时钟
timedatectl set-ntp true

# 磁盘设备
DISK1="/dev/sda"
DISK2="/dev/sdb"

# 格式化磁盘并设置为GPT分区表
sgdisk --zap-all $DISK1
sgdisk --zap-all $DISK2
sgdisk -g $DISK1
sgdisk -g $DISK2

# 分区sdb：EFI分区、交换分区、根分区
sgdisk -n 1:0:+512M -t 1:ef00 $DISK2
sgdisk -n 2:0:+8G -t 2:8200 $DISK2
sgdisk -n 3:0:0 -t 3:8300 $DISK2

# 分区sda：home分区
sgdisk -n 1:0:0 -t 1:8302 $DISK1

# 格式化分区
mkfs.fat -F32 ${DISK2}1
mkswap ${DISK2}2
mkfs.ext4 ${DISK2}3
mkfs.ext4 ${DISK1}1

# 启用交换分区
swapon ${DISK2}2

# 挂载分区
mount ${DISK2}3 /mnt
mkdir -p /mnt/boot
mount ${DISK2}1 /mnt/boot
mkdir -p /mnt/home
mount ${DISK1}1 /mnt/home

# 启用32位支持库
sed -i 's/#\[multilib\]/\[multilib\]/' /etc/pacman.conf
sed -i '/\[multilib\]/{n;s/#Include/Include/}' /etc/pacman.conf

# 添加中文源
echo '[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch' >> /etc/pacman.conf

# 更新软件包数据库
pacman -Sy

# 安装基本系统和其他软件包
pacstrap /mnt base base-devel linux linux-headers linux-firmware intel-ucode iwd dhcpcd vim bash-completion plasma-desktop sddm xorg-server \
noto-fonts-cjk git wget bind ntfs-3g alsa-utils ark packagekit-qt5 fcitx fcitx-im fcitx-configtool fcitx-sunpinyin zsh bluez bluez-utils bluedevil

# 生成fstab文件
genfstab -U /mnt >> /mnt/etc/fstab

# 进入新系统
arch-chroot /mnt <<EOF

# 设置时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# 本地化配置
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# 设置主机名
echo "ll" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 ll.localdomain ll" >> /etc/hosts

# 设置root密码
echo "root:password" | chpasswd

# 创建qv2ray用户组
groupadd qv2ray

# 创建普通用户并添加到wheel和qv2ray组
useradd -m -G wheel,qv2ray -s /bin/zsh ll
echo "ll:password" | chpasswd

# 配置sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# 设置DNS
cat <<EOT >> /etc/systemd/resolved.conf
[Resolve]
DNS=8.8.8.8 8.8.4.4
DNS=2001:4860:4860::8888 2001:4860:4860::8844
FallbackDNS=8.8.8.8 8.8.4.4
EOT

# 启用systemd-resolved
systemctl enable systemd-resolved
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 启用32位支持库
sed -i 's/#\[multilib\]/\[multilib\]/' /etc/pacman.conf
sed -i '/\[multilib\]/{n;s/#Include/Include/}' /etc/pacman.conf

# 添加中文源
echo '[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch' >> /etc/pacman.conf

# 更新软件包数据库
pacman -Sy

# 安装archlinuxcn-keyring
pacman -S --noconfirm archlinuxcn-keyring

# 安装引导程序
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 启用并启动必要的服务
systemctl enable dhcpcd
systemctl enable iwd
systemctl enable sddm
systemctl enable bluetooth

# 设置系统语言为中文
localectl set-locale LANG=zh_CN.UTF-8
localectl set-keymap us

# 安装yay
pacman -S --noconfirm yay

# 配置输入法
cat <<EOT >> /etc/environment
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOT

# 将vim设置为默认编辑器
echo "export EDITOR=vim" >> /etc/profile

# 安装oh-my-zsh
su - ll <<'EOT'
yay -S --noconfirm oh-my-zsh-git
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
EOT

# 安装qv2ray和v2ray核心及测速插件
yay -S --noconfirm qv2ray v2ray qv2ray-plugin-speedtest

# 退出chroot
EOF

# 卸载分区并重新启动
umount -R /mnt
echo "安装完成。请重新启动系统。"

