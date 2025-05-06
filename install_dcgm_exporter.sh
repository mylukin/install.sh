#!/bin/bash

set -e

# 检查并安装 Docker
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
fi

# 检查 NVIDIA 驱动和 Container Toolkit
if ! command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA 驱动未安装，请先安装 NVIDIA 驱动。"
    exit 1
fi

if ! docker info | grep -i 'Runtimes' | grep -q 'nvidia'; then
    echo "NVIDIA Container Toolkit 未安装，正在安装..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    sudo systemctl restart docker
fi

# 拉取并运行最新的 DCGM Exporter 镜像
echo "正在拉取并运行 DCGM Exporter..."
docker run -d --gpus all --restart=always \
  -p 9400:9400 \
  --name dcgm-exporter \
  --cap-add SYS_ADMIN \
  nvcr.io/nvidia/k8s/dcgm-exporter:4.2.0-4.1.0-ubuntu22.04
