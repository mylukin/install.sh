#!/bin/bash

# Docker 一键安装脚本 - Ubuntu Server 24.04
# 作者: Claude AI
# 版本: 1.1
# 使用方法: 
#   安装Docker: chmod +x install_docker.sh && ./install_docker.sh
#   修复权限: ./install_docker.sh --fix-permissions

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到以root用户运行，建议使用普通用户运行此脚本"
        read -p "是否继续? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检查系统版本
check_system() {
    log_info "检查系统版本..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "此脚本仅支持Ubuntu系统，当前系统: $ID"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        log_warning "此脚本针对Ubuntu 24.04优化，当前版本: $VERSION_ID"
        read -p "是否继续安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "系统检查通过: Ubuntu $VERSION_ID"
}

# 检查Docker是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null; then
        log_warning "检测到Docker已安装"
        docker --version
        read -p "是否重新安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "退出安装程序"
            exit 0
        fi
    fi
}

# 更新系统
update_system() {
    log_info "更新系统包..."
    sudo apt update && sudo apt upgrade -y
    log_success "系统更新完成"
}

# 安装必要的依赖
install_dependencies() {
    log_info "安装依赖包..."
    sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        gnupg \
        lsb-release
    log_success "依赖包安装完成"
}

# 添加Docker官方GPG密钥
add_docker_gpg_key() {
    log_info "添加Docker官方GPG密钥..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    log_success "GPG密钥添加完成"
}

# 添加Docker仓库
add_docker_repository() {
    log_info "添加Docker官方仓库..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    log_success "Docker仓库添加完成"
}

# 安装Docker
install_docker() {
    log_info "安装Docker CE..."
    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    log_success "Docker安装完成"
}

# 启动并启用Docker服务
start_docker_service() {
    log_info "启动Docker服务..."
    sudo systemctl start docker
    sudo systemctl enable docker
    log_success "Docker服务已启动并设置为开机自启"
}

# 将当前用户添加到docker组
add_user_to_docker_group() {
    log_info "将当前用户添加到docker组..."
    sudo usermod -aG docker $USER
    log_success "用户已添加到docker组"
    
    # 检查当前shell是否已在docker组中
    if ! groups $USER | grep -q docker; then
        log_warning "当前shell session还没有docker组权限"
    fi
}

# 修复Docker权限问题
fix_docker_permissions() {
    log_info "检查和修复Docker权限..."
    
    # 检查Docker socket权限
    if [[ ! -S /var/run/docker.sock ]]; then
        log_error "Docker socket不存在"
        return 1
    fi
    
    # 检查当前用户是否在docker组中
    if ! id -nG "$USER" | grep -qw docker; then
        log_warning "当前用户不在docker组中，正在添加..."
        sudo usermod -aG docker $USER
    fi
    
    # 确保Docker socket有正确的权限
    sudo chmod 666 /var/run/docker.sock
    
    # 尝试立即获取docker组权限
    log_info "尝试激活docker组权限..."
    
    # 方法1: 使用newgrp (在子shell中)
    log_info "可以运行以下命令立即获得Docker权限:"
    echo "  方法1: newgrp docker"
    echo "  方法2: sudo chmod 666 /var/run/docker.sock (临时解决)"
    echo "  方法3: 注销并重新登录"
    
    log_success "权限修复完成"
}

# 测试Docker权限
test_docker_permissions() {
    log_info "测试Docker权限..."
    
    # 首先尝试不使用sudo
    if docker ps &> /dev/null; then
        log_success "Docker权限正常"
        return 0
    else
        log_warning "Docker权限不足，尝试修复..."
        
        # 临时修复权限
        sudo chmod 666 /var/run/docker.sock
        
        if docker ps &> /dev/null; then
            log_success "Docker权限修复成功（临时）"
            log_warning "建议注销重新登录以获得永久权限"
            return 0
        else
            log_error "Docker权限修复失败"
            return 1
        fi
    fi
}

# 验证安装
verify_installation() {
    log_info "验证Docker安装..."
    
    # 检查Docker版本
    echo "Docker版本信息:"
    sudo docker --version
    sudo docker compose version
    
    # 检查Docker服务状态
    if sudo systemctl is-active --quiet docker; then
        log_success "Docker服务运行正常"
    else
        log_error "Docker服务未运行"
        return 1
    fi
    
    # 测试权限
    test_docker_permissions
    
    # 运行测试容器（优先使用非sudo）
    log_info "运行测试容器..."
    if docker run --rm hello-world &> /dev/null 2>&1; then
        log_success "Docker测试容器运行成功（无需sudo）"
    elif sudo docker run --rm hello-world &> /dev/null; then
        log_success "Docker测试容器运行成功（需要sudo）"
        log_warning "建议解决权限问题以避免使用sudo"
    else
        log_error "Docker测试容器运行失败"
        return 1
    fi
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 这里可以添加清理逻辑
}

# 显示安装后信息
show_post_install_info() {
    echo
    log_success "============================================"
    log_success "Docker安装完成！"
    log_success "============================================"
    echo
    
    # 检查当前是否有Docker权限
    if docker ps &> /dev/null; then
        log_success "✅ Docker权限配置正常，可以直接使用"
        echo "  测试命令: docker run hello-world"
    else
        log_warning "⚠️  需要激活Docker权限，请选择以下方法之一:"
        echo
        echo "  方法1 (推荐): 注销并重新登录"
        echo "  方法2 (立即生效): newgrp docker"
        echo "  方法3 (临时): sudo chmod 666 /var/run/docker.sock"
        echo
        log_info "如果仍有权限问题，运行以下命令:"
        echo "  sudo usermod -aG docker \$USER"
        echo "  sudo chmod 666 /var/run/docker.sock"
        echo "  newgrp docker"
    fi
    
    echo
    log_info "常用命令:"
    echo "  查看Docker版本: docker --version"
    echo "  查看运行的容器: docker ps"
    echo "  查看所有容器: docker ps -a"
    echo "  查看镜像: docker images"
    echo "  运行容器: docker run [镜像名]"
    echo "  使用Docker Compose: docker compose [命令]"
    echo
    log_info "故障排除:"
    echo "  如果遇到权限错误，请运行: newgrp docker"
    echo "  或者注销重新登录"
    echo
    log_info "文档: https://docs.docker.com/"
}

# 错误处理
error_handler() {
    log_error "安装过程中发生错误，正在清理..."
    cleanup
    exit 1
}

# 主函数
main() {
    # 检查命令行参数
    if [[ "$1" == "--fix-permissions" || "$1" == "-f" ]]; then
        echo "=========================================="
        echo "         Docker 权限修复工具"
        echo "=========================================="
        echo
        fix_docker_permissions
        test_docker_permissions
        echo
        log_info "权限修复完成！现在尝试运行: docker ps"
        return 0
    fi
    
    echo "=========================================="
    echo "    Docker 一键安装脚本 - Ubuntu 24.04"
    echo "=========================================="
    echo
    log_info "使用参数 --fix-permissions 或 -f 仅修复权限问题"
    echo
    
    # 设置错误处理
    trap error_handler ERR
    
    # 执行安装步骤
    check_root
    check_system
    check_docker_installed
    
    log_info "开始安装Docker..."
    
    update_system
    install_dependencies
    add_docker_gpg_key
    add_docker_repository
    install_docker
    start_docker_service
    add_user_to_docker_group
    fix_docker_permissions
    verify_installation
    
    show_post_install_info
    
    log_success "安装完成！"
}

# 运行主函数
main "$@"
