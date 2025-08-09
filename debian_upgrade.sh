#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要root权限运行。请使用sudo运行。"
        exit 1
    fi
}

get_current_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$VERSION_ID"
    else
        error "无法检测当前Debian版本"
        exit 1
    fi
}

get_version_codename() {
    case $1 in
        10) echo "buster" ;;
        11) echo "bullseye" ;;
        12) echo "bookworm" ;;
        13) echo "trixie" ;;
        *) echo "unknown" ;;
    esac
}

get_next_version() {
    local current=$1
    case $current in
        10) echo "11" ;;
        11) echo "12" ;;
        12) echo "13" ;;
        13) echo "none" ;;
        *) echo "none" ;;
    esac
}

backup_sources() {
    log "备份当前sources.list文件..."
    cp /etc/apt/sources.list "/etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -d /etc/apt/sources.list.d ]]; then
        cp -r /etc/apt/sources.list.d "/etc/apt/sources.list.d.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

update_sources_list() {
    local target_codename=$1
    log "更新sources.list到 $target_codename..."
    
    cat > /etc/apt/sources.list << EOF
# Debian $target_codename repositories
deb http://deb.debian.org/debian $target_codename main contrib non-free
deb-src http://deb.debian.org/debian $target_codename main contrib non-free

deb http://security.debian.org/debian-security $target_codename-security main contrib non-free
deb-src http://security.debian.org/debian-security $target_codename-security main contrib non-free

deb http://deb.debian.org/debian $target_codename-updates main contrib non-free
deb-src http://deb.debian.org/debian $target_codename-updates main contrib non-free
EOF
}

upgrade_system_packages() {
    log "更新软件包列表..."
    apt update
    
    log "升级当前系统软件包..."
    apt upgrade -y
    
    log "执行完整升级..."
    apt full-upgrade -y
    
    log "清理不需要的软件包..."
    apt autoremove -y
    apt autoclean
}

upgrade_to_next_version() {
    local current_version=$1
    local next_version=$(get_next_version $current_version)
    
    if [[ "$next_version" == "none" ]]; then
        if [[ "$current_version" == "13" ]]; then
            log "您已经在最新的Debian 13版本！"
        else
            error "不支持从Debian $current_version 升级"
        fi
        return 1
    fi
    
    local next_codename=$(get_version_codename $next_version)
    
    echo
    warn "准备从 Debian $current_version 升级到 Debian $next_version ($next_codename)"
    warn "这个过程可能需要很长时间，并且有一定风险。"
    echo
    read -p "您确定要继续吗？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "升级已取消"
        return 0
    fi
    
    backup_sources
    
    log "开始升级过程..."
    
    log "第一步：更新当前系统..."
    upgrade_system_packages
    
    log "第二步：更新软件源..."
    update_sources_list $next_codename
    
    log "第三步：更新软件包列表..."
    apt update
    
    log "第四步：执行系统升级..."
    apt upgrade -y
    apt full-upgrade -y
    
    log "第五步：清理系统..."
    apt autoremove -y
    apt autoclean
    
    log "升级完成！建议重启系统。"
    echo
    read -p "现在重启系统吗？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "正在重启系统..."
        reboot
    else
        warn "请尽快重启系统以完成升级过程。"
    fi
}

show_menu() {
    local current_version=$1
    local current_codename=$(get_version_codename $current_version)
    local next_version=$(get_next_version $current_version)
    local next_codename=$(get_version_codename $next_version)
    
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    Debian 系统升级脚本${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo -e "当前版本: ${GREEN}Debian $current_version ($current_codename)${NC}"
    
    if [[ "$next_version" != "none" ]]; then
        echo -e "可升级到: ${YELLOW}Debian $next_version ($next_codename)${NC}"
    else
        if [[ "$current_version" == "13" ]]; then
            echo -e "状态: ${GREEN}已是最新版本${NC}"
        else
            echo -e "状态: ${RED}不支持升级${NC}"
        fi
    fi
    
    echo
    echo "请选择操作："
    echo "1) 升级当前版本软件包"
    if [[ "$next_version" != "none" ]]; then
        echo "2) 升级到下一个系统版本 (Debian $next_version)"
    else
        echo "2) 升级到下一个系统版本 (不可用)"
    fi
    echo "3) 查看升级历史"
    echo "0) 退出"
    echo
}

show_upgrade_history() {
    echo
    echo -e "${BLUE}Debian 版本升级路径:${NC}"
    echo "Debian 10 (buster) → Debian 11 (bullseye)"
    echo "Debian 11 (bullseye) → Debian 12 (bookworm)"
    echo "Debian 12 (bookworm) → Debian 13 (trixie)"
    echo
    echo "注意：不支持跨版本升级（如直接从10升级到12）"
    echo "必须按顺序逐步升级以确保系统稳定性"
    echo
    read -p "按回车键返回主菜单..." -r
}

main() {
    check_root
    
    local current_version=$(get_current_version)
    
    if [[ ! "$current_version" =~ ^(10|11|12|13)$ ]]; then
        error "检测到不支持的Debian版本: $current_version"
        error "此脚本仅支持Debian 10-13"
        exit 1
    fi
    
    while true; do
        show_menu $current_version
        
        read -p "请输入选择 [0-3]: " choice
        echo
        
        case $choice in
            1)
                log "开始升级当前版本软件包..."
                upgrade_system_packages
                echo
                read -p "按回车键继续..." -r
                ;;
            2)
                if [[ "$(get_next_version $current_version)" != "none" ]]; then
                    upgrade_to_next_version $current_version
                    current_version=$(get_current_version)
                else
                    error "当前版本不支持系统升级"
                    read -p "按回车键继续..." -r
                fi
                ;;
            3)
                show_upgrade_history
                ;;
            0)
                log "退出脚本"
                exit 0
                ;;
            *)
                error "无效选择，请重新输入"
                read -p "按回车键继续..." -r
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi