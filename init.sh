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
apt-get install -y neofetch vim zip curl vnstat zsh sudo iperf3 git

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
fs.file-max=1000000
fs.inotify.max_user_instances=65536

net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.ipv4.ip_local_port_range = 2000 65535
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_retries1=3
net.ipv4.tcp_retries2=5
net.ipv4.tcp_orphan_retries=3
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_max_tw_buckets=10000
net.ipv4.tcp_max_syn_backlog=131072
net.core.netdev_max_backlog=131072
net.core.somaxconn=32768
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=-2
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=335544320
net.core.wmem_max=335544320
net.ipv4.tcp_rmem=8192 262144 536870912
net.ipv4.tcp_wmem=4096 16384 536870912
net.ipv4.tcp_collapse_max_bytes = 6291456
net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_mem=262144 1048576 4194304
net.ipv4.udp_mem=262144 1048576 4194304
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.ping_group_range=0 2147483647
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

yes | curl -k -sSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sed "s/\$REMOTE/https:\/\/github.com\/ohmyzsh\/ohmyzsh.git/g" | sed "/.*exec zsh.*/d" > $HOME/.temp

cat <<EOF >> $HOME/.temp
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "\$ZSH/custom/themes/spaceship-prompt" --depth=1
ln -s "\$ZSH/custom/themes/spaceship-prompt/spaceship.zsh-theme" "\$ZSH/custom/themes/spaceship.zsh-theme"
echo -e "\n"
git clone https://github.com/zsh-users/zsh-autosuggestions.git \${ZSH:-~/.oh-my-zsh}/custom/plugins/zsh-autosuggestions
echo -e "\n"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \${ZSH:-~/.oh-my-zsh}/custom/plugins/zsh-syntax-highlighting
echo -e "\n"
git clone https://github.com/conda-incubator/conda-zsh-completion.git \${ZSH:-~/.oh-my-zsh}/custom/plugins/conda-zsh-completion
echo -e "\n"
EOF

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

exec zsh -l

echo "Initialization complete!"
exit 0
