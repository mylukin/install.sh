#!/bin/bash

set -e

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请以 root 用户运行此脚本。"
  exit 1
fi

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
  echo "Docker 未安装，正在安装..."
  apt-get update
  apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# 检查 NVIDIA Container Toolkit 是否已安装
if ! dpkg -l | grep -q nvidia-container-toolkit; then
  echo "NVIDIA Container Toolkit 未安装，正在安装..."
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
  curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

  apt-get update
  apt-get install -y nvidia-container-toolkit
  systemctl restart docker
fi

# 拉取并运行 DCGM Exporter 容器
echo "正在拉取并运行 DCGM Exporter 容器..."
docker run -d --gpus all --restart=always \
  -p 9400:9400 \
  --name dcgm-exporter \
  --cap-add SYS_ADMIN \
  nvcr.io/nvidia/k8s/dcgm-exporter:4.2.0-4.1.0-ubuntu22.04

echo "DCGM Exporter 已成功安装并运行。您可以通过访问 http://<服务器IP>:9400/metrics 查看指标。"
