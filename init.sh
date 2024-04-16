#!/bin/bash

# 更换apt源为官方源
echo "Updating APT sources..."
cat > /etc/apt/sources.list << EOF
deb https://deb.debian.org/debian/ bullseye main contrib non-free
deb-src https://deb.debian.org/debian/ bullseye main contrib non-free

deb https://deb.debian.org/debian/ bullseye-updates main contrib non-free
deb-src https://deb.debian.org/debian/ bullseye-updates main contrib non-free

deb https://deb.debian.org/debian/ bullseye-backports main contrib non-free
deb-src https://deb.debian.org/debian/ bullseye-backports main contrib non-free

deb https://deb.debian.org/debian-security/ bullseye-security main contrib non-free
deb-src https://deb.debian.org/debian-security/ bullseye-security main contrib non-free
EOF

# 更新软件包
echo "Updating package list..."
apt-get update -y
apt-get upgrade -y

# 安装必要的软件
echo "Installing necessary software..."
apt-get install -y htop atop neofetch vim git zip curl vnstat zsh sudo iperf3

# 安装Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | bash -s docker

# 启动Docker服务
systemctl start docker

# 开启BBR
echo "Enabling BBR..."
modprobe tcp_bbr
echo "tcp_bbr" | tee --append /etc/modules-load.d/modules.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 更新sysctl.conf文件
echo "Writing to /etc/sysctl.conf..."
cat <<EOT >> /etc/sysctl.conf
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOT

# 加载新的网络配置
sysctl -p

# 配置zsh
echo "Configuring zsh..."
if ! which git > /dev/null 2>&1; then
    echo -e "\ngit is not found.\nexit with code 1.\n"
    exit 1
elif ! which curl > /dev/null 2>&1; then
    echo -e "\ncurl is not found.\nexit with code 1.\n"
    exit 1
fi

curl -k -sSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sed "s/\$REMOTE/https:\/\/github.com\/ohmyzsh\/ohmyzsh.git/g" | sed "/.*exec zsh.*/d" > $HOME/.temp

sh $HOME/.temp
rm -rf $HOME/.temp

sed -i "s/ZSH_THEME=\".*/ZSH_THEME=\"ys\"/g" $HOME/.zshrc
sed -i "s/plugins=(git)/plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting conda-zsh-completion pip ufw docker docker-compose extract command-not-found z colorize colored-man-pages)/g" $HOME/.zshrc
cat <<EOF >> $HOME/.zshrc
# 关闭 git 显示
SPACESHIP_GIT_SHOW=false
# 关闭 node 显示
SPACESHIP_NODE_SHOW=false
# 关闭 maven 显示
SPACESHIP_MAVEN_SHOW=false
# 关闭 package 显示
SPACESHIP_PACKAGE_SHOW=false

zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes
EOF

# 更改默认的 shell 为 zsh
if ! chsh -s $(which zsh); then
    echo "chsh command unsuccessful. Change your default shell manually."
fi

# Configure snell
echo "Configuring Snell..."
mkdir -p /root/snelldocker

cat > /root/snelldocker/docker-compose.yml << EOF
version: "3.8" 
services:
  snell:
    image: accors/snell:latest
    container_name: snell
    restart: always
    network_mode: host
    volumes:
      - ./snell.conf:/etc/snell-server.conf
    environment:
      - SNELL_URL=https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-amd64.zip
EOF

cat > /root/snelldocker/snell.conf << EOF
[snell-server]
listen = ::0:14250
psk = 8QYc9zTowGlChZDIce684lNcD5k6DhE
ipv6 = true
obfs = http
EOF

cd /root/snelldocker && docker-compose pull && docker-compose up -d

cd ~

exec zsh -l

echo "Initialization complete!"
exit 0
