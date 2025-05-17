#!/usr/bin/env bash
set -e

echo "📦 开始安装 audiowmark（含最新 automake）..."

# 检查系统平台
OS=$(uname)
echo "🔍 当前系统：$OS"

# 安装构建依赖
if [ "$OS" == "Linux" ]; then
    echo "📦 安装 Ubuntu 构建依赖 ..."
    sudo apt update
    sudo apt install -y git build-essential autoconf libtool \
        libfftw3-dev libsndfile1-dev libgcrypt20-dev \
        libzita-resampler-dev libmpg123-dev lame wget curl
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

# ⚙️ 安装最新版 automake（Ubuntu Only）
if [ "$OS" == "Linux" ]; then
    echo "⬇️ 安装 automake 1.16.5 ..."
    cd /tmp
    wget https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz
    tar -xzf automake-1.16.5.tar.gz
    cd automake-1.16.5
    ./configure --prefix=/usr/local
    make -j$(nproc)
    sudo make install

    export PATH="/usr/local/bin:$PATH"
    echo "✅ 已使用新版 automake：$(automake --version | head -n1)"
fi

# 📁 创建工作目录
WORKDIR="$HOME/audiowmark_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 下载 audiowmark
if [ ! -d "audiowmark" ]; then
    echo "📥 克隆 audiowmark 仓库 ..."
    git clone https://github.com/swesterfeld/audiowmark.git
fi

cd audiowmark

echo "⚙️ 开始构建 audiowmark ..."
./autogen.sh
./configure
make -j$(nproc)

echo "🚀 安装到系统路径 ..."
sudo make install

echo "✅ 验证安装 ..."
audiowmark --version

echo "🎉 安装完成！audiowmark 已可用。"
