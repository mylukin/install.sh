#!/bin/bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 用户运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "请以 root 用户运行此脚本。"
        exit 1
    fi
}

# 检查 NVIDIA GPU 和驱动
check_nvidia() {
    log_info "检查 NVIDIA GPU 和驱动..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "未找到 nvidia-smi 命令，请确保已安装 NVIDIA 驱动。"
        exit 1
    fi
    
    # 检查 GPU 是否可用
    if ! nvidia-smi &> /dev/null; then
        log_error "NVIDIA 驱动未正常工作，请检查驱动安装。"
        exit 1
    fi
    
    log_info "NVIDIA 驱动检查通过。"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
}

# 检查 CUDA 是否已安装
check_cuda() {
    log_info "检查 CUDA 安装状态..."
    
    if command -v nvcc &> /dev/null; then
        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
        log_info "检测到 CUDA 版本: $CUDA_VERSION"
        return 0
    elif [ -d "/usr/local/cuda" ]; then
        log_info "检测到 CUDA 安装目录: /usr/local/cuda"
        return 0
    else
        log_warn "未检测到 CUDA 安装。"
        read -p "是否要安装 CUDA 12.9.1？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_cuda
        else
            log_info "跳过 CUDA 安装，假设您已手动安装。"
        fi
        return 0
    fi
}

# 安装 CUDA Toolkit
install_cuda() {
    log_info "正在下载并安装 CUDA 12.9.1..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # 下载 CUDA 安装包
    log_info "下载 CUDA 安装包..."
    wget -O cuda_12.9.1_575.57.08_linux.run \
        https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda_12.9.1_575.57.08_linux.run
    
    # 验证下载
    if [ ! -f "cuda_12.9.1_575.57.08_linux.run" ]; then
        log_error "CUDA 安装包下载失败。"
        exit 1
    fi
    
    # 添加执行权限
    chmod +x cuda_12.9.1_575.57.08_linux.run
    
    # 安装 CUDA（不安装驱动，因为驱动已存在）
    log_info "安装 CUDA Toolkit（跳过驱动安装）..."
    ./cuda_12.9.1_575.57.08_linux.run --silent --toolkit --no-opengl-libs
    
    # 设置环境变量
    if ! grep -q "/usr/local/cuda/bin" /etc/environment; then
        echo 'PATH="/usr/local/cuda/bin:$PATH"' >> /etc/environment
    fi
    
    # 创建符号链接
    if [ ! -L /usr/local/cuda ]; then
        ln -sf /usr/local/cuda-12.9 /usr/local/cuda
    fi
    
    # 添加库路径
    echo '/usr/local/cuda/lib64' > /etc/ld.so.conf.d/cuda.conf
    ldconfig
    
    # 清理临时文件
    cd /
    rm -rf "$TEMP_DIR"
    
    log_info "CUDA 12.9.1 安装完成。"
    log_warn "请重新登录以使环境变量生效，或运行: source /etc/environment"
}

# 安装 Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装，版本: $(docker --version)"
        return 0
    fi

    log_info "Docker 未安装，正在安装..."
    
    # 更新包索引
    apt-get update
    
    # 安装必要的包
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        wget

    # 添加 Docker 官方 GPG 密钥
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # 添加 Docker 仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 更新包索引并安装 Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 启动并启用 Docker 服务
    systemctl start docker
    systemctl enable docker

    log_info "Docker 安装完成。"
}

# 安装 NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    if dpkg -l | grep -q nvidia-container-toolkit; then
        log_info "NVIDIA Container Toolkit 已安装。"
        return 0
    fi

    log_info "NVIDIA Container Toolkit 未安装，正在安装..."
    
    # 使用官方推荐的最新安装方法
    log_info "配置 NVIDIA Container Toolkit 仓库..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    # 更新包列表
    log_info "更新软件包列表..."
    apt-get update

    # 安装 NVIDIA Container Toolkit
    log_info "安装 NVIDIA Container Toolkit..."
    apt-get install -y nvidia-container-toolkit

    # 配置 Docker 运行时
    log_info "配置 Docker 运行时..."
    nvidia-ctk runtime configure --runtime=docker
    
    # 重启 Docker 服务
    log_info "重启 Docker 服务..."
    systemctl restart docker

    log_info "NVIDIA Container Toolkit 安装完成。"
}

# 测试 NVIDIA Docker 集成
test_nvidia_docker() {
    log_info "测试 NVIDIA Docker 集成..."
    
    # 首先尝试拉取测试镜像
    log_info "拉取 CUDA 测试镜像..."
    if ! docker pull nvidia/cuda:12.9.0-base-ubuntu22.04; then
        log_error "无法拉取 CUDA 测试镜像。"
        exit 1
    fi
    
    # 测试 GPU 访问
    log_info "运行 GPU 访问测试..."
    local test_output
    test_output=$(docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_info "NVIDIA Docker 集成测试通过。"
        echo "GPU 信息："
        echo "$test_output" | grep -E "(GeForce|RTX|GTX|Tesla|Quadro|Driver Version)"
    else
        log_error "NVIDIA Docker 集成测试失败。"
        log_error "错误输出："
        echo "$test_output"
        
        # 提供调试信息
        log_info "调试信息："
        log_info "1. 检查 Docker 配置："
        cat /etc/docker/daemon.json 2>/dev/null || echo "daemon.json 文件不存在"
        
        log_info "2. 检查 nvidia-ctk 配置："
        nvidia-ctk --version
        
        log_info "3. 重新配置并重启 Docker..."
        nvidia-ctk runtime configure --runtime=docker
        systemctl restart docker
        sleep 5
        
        # 再次测试
        log_info "重新测试 GPU 访问..."
        if docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi; then
            log_info "重新配置后测试成功。"
        else
            log_error "重新配置后仍然失败，请手动检查配置。"
            exit 1
        fi
    fi
}

# 停止并删除现有的 DCGM Exporter 容器
cleanup_existing_container() {
    if docker ps -a --format "table {{.Names}}" | grep -q "dcgm-exporter"; then
        log_info "发现存在的 DCGM Exporter 容器，正在清理..."
        docker stop dcgm-exporter &> /dev/null || true
        docker rm dcgm-exporter &> /dev/null || true
        log_info "现有容器已清理。"
    fi
}

# 拉取并运行 DCGM Exporter 容器
deploy_dcgm_exporter() {
    log_info "正在拉取 DCGM Exporter 镜像..."
    docker pull nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-ubuntu22.04

    log_info "正在启动 DCGM Exporter 容器..."
    docker run -d \
        --name dcgm-exporter \
        --restart=unless-stopped \
        --gpus all \
        --cap-add SYS_ADMIN \
        --pid=host \
        -p 9400:9400 \
        -v /var/lib/nvidia/:/var/lib/nvidia/:ro \
        nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-ubuntu22.04

    # 等待容器启动
    sleep 5

    # 检查容器状态
    if docker ps | grep -q dcgm-exporter; then
        log_info "DCGM Exporter 容器启动成功。"
    else
        log_error "DCGM Exporter 容器启动失败。"
        docker logs dcgm-exporter
        exit 1
    fi
}

# 验证 DCGM Exporter 是否正常工作
verify_dcgm_exporter() {
    log_info "验证 DCGM Exporter 是否正常工作..."
    
    # 等待服务完全启动
    sleep 10
    
    if curl -s http://localhost:9400/metrics | grep -q "DCGM_FI_DEV_GPU_UTIL"; then
        log_info "DCGM Exporter 工作正常，指标可访问。"
    else
        log_warn "无法获取 DCGM 指标，请检查容器日志："
        docker logs dcgm-exporter
    fi
}

# 显示安装完成信息
show_completion_info() {
    local SERVER_IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo
    log_info "======================== 安装完成 ========================"
    log_info "DCGM Exporter 已成功安装并运行！"
    echo
    log_info "访问方式："
    log_info "  本地访问: http://localhost:9400/metrics"
    log_info "  远程访问: http://${SERVER_IP}:9400/metrics"
    echo
    log_info "容器管理命令："
    log_info "  查看状态: docker ps | grep dcgm-exporter"
    log_info "  查看日志: docker logs dcgm-exporter"
    log_info "  重启容器: docker restart dcgm-exporter"
    log_info "  停止容器: docker stop dcgm-exporter"
    echo
    log_info "==========================================================="
}

# 主函数
main() {
    log_info "开始安装 DCGM Exporter..."
    
    check_root
    check_nvidia
    check_cuda
    install_docker
    install_nvidia_container_toolkit
    test_nvidia_docker
    cleanup_existing_container
    deploy_dcgm_exporter
    verify_dcgm_exporter
    show_completion_info
}

# 错误处理
trap 'log_error "脚本执行失败，请检查上述错误信息。"' ERR

# 执行主函数
main "$@"
