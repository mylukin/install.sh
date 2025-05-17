#!/usr/bin/env bash
set -e

echo "📦 开始安装 audiowmark ..."

# 检查系统平台
OS=$(uname)
echo "🔍 当前系统：$OS"

# 安装构建依赖
if [ "$OS" == "Linux" ]; then
    echo "📦 安装 Ubuntu 构建依赖 ..."
    sudo apt update
    sudo apt install -y git build-essential autoconf \
        libfftw3-dev libsndfile1-dev libgcrypt20-dev \
        libzita-resampler-dev libmpg123-dev lame
elif [ "$OS" == "Darwin" ]; then
    echo "📦 安装 macOS 构建依赖 ..."
    if ! command -v brew &> /dev/null; then
        echo "❌ 未安装 Homebrew，请先安装：https://brew.sh/"
        exit 1
    fi
    brew install fftw libsndfile libgcrypt zita-resampler mpg123 lame autoconf automake
else
    echo "❌ 不支持的平台：$OS"
    exit 1
fi

# 下载 audiowmark 源码
WORKDIR="$HOME/audiowmark_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "audiowmark" ]; then
    echo "📥 克隆 audiowmark 仓库 ..."
    git clone https://github.com/swesterfeld/audiowmark.git
fi

cd audiowmark
echo "⚙️ 开始构建 ..."

# 初始化并构建
./autogen.sh
./configure
make -j$(nproc)

# 安装到系统路径（可选）
echo "🚀 安装到系统中 ..."
sudo make install

# 验证安装
echo "✅ 验证版本："
audiowmark --version

echo "🎉 安装完成！audiowmark 已可用"
