#!/usr/bin/env bash
set -e

# 打印彩色输出函数
print_info() { echo -e "\033[1;34m🔍 $1\033[0m"; }
print_step() { echo -e "\033[1;32m📦 $1\033[0m"; }
print_warn() { echo -e "\033[1;33m⚠️ $1\033[0m"; }
print_error() { echo -e "\033[1;31m❌ $1\033[0m"; }
print_success() { echo -e "\033[1;32m✅ $1\033[0m"; }

print_step "开始安装 audiowmark（含最新构建工具）..."

# 检查系统平台
OS=$(uname)
print_info "当前系统：$OS"

# 安装构建依赖
if [ "$OS" == "Linux" ]; then
    print_step "安装 Ubuntu 构建依赖 ..."
    sudo apt update
    sudo apt install -y git build-essential autoconf libtool pkg-config \
        libfftw3-dev libsndfile1-dev libgcrypt20-dev \
        libzita-resampler-dev libmpg123-dev lame wget curl \
        autoconf-archive  # 添加 autoconf-archive，提供 pkg.m4 宏

elif [ "$OS" == "Darwin" ]; then
    print_step "安装 macOS 构建依赖 ..."
    if ! command -v brew &> /dev/null; then
        print_error "未安装 Homebrew，请先安装：https://brew.sh/"
        exit 1
    fi
    brew install fftw libsndfile libgcrypt zita-resampler mpg123 lame \
        autoconf automake pkg-config autoconf-archive  # 添加 autoconf-archive
else
    print_error "不支持的平台：$OS"
    exit 1
fi

# ⚙️ 安装最新版 automake（仅 Linux）
if [ "$OS" == "Linux" ]; then
    print_step "安装 automake 1.16.5 ..."
    cd /tmp
    wget https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz
    tar -xzf automake-1.16.5.tar.gz
    cd automake-1.16.5
    ./configure --prefix=/usr/local
    make -j$(nproc)
    sudo make install
    export PATH="/usr/local/bin:$PATH"
    print_success "已使用新版 automake：$(automake --version | head -n1)"
    
    # 确保 pkg.m4 宏可用（Linux）
    print_step "确保 pkg-config 宏可用..."
    if [ -f /usr/share/aclocal/pkg.m4 ]; then
        sudo mkdir -p /usr/local/share/aclocal
        sudo cp /usr/share/aclocal/pkg.m4 /usr/local/share/aclocal/ 2>/dev/null || true
        print_success "已复制 pkg.m4 到 /usr/local/share/aclocal/"
    else
        print_warn "找不到 pkg.m4 文件，尝试从 pkg-config 包获取..."
        sudo apt install -y pkg-config
    fi
fi

# 📁 创建工作目录
WORKDIR="$HOME/audiowmark_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 清理和下载 audiowmark
FORCE_CLEAN=false  # 可以设置为 true 强制重新构建
if [ "$FORCE_CLEAN" = true ] && [ -d "audiowmark" ]; then
    print_warn "强制清理先前的构建..."
    rm -rf audiowmark
fi

if [ ! -d "audiowmark" ]; then
    print_step "克隆 audiowmark 仓库 ..."
    git clone https://github.com/swesterfeld/audiowmark.git
else
    print_step "更新 audiowmark 仓库 ..."
    cd audiowmark
    git pull
    cd ..
fi

cd audiowmark

# 清理任何可能的旧配置
print_step "清理先前的配置..."
rm -rf autom4te.cache
[ -f Makefile ] && make distclean || true

print_step "开始构建 audiowmark ..."
print_info "运行 autogen.sh ..."
./autogen.sh

# 如果 autogen.sh 失败，尝试手动重新生成配置
if [ $? -ne 0 ]; then
    print_warn "autogen.sh 失败，尝试手动重新生成配置..."
    aclocal
    automake --add-missing
    autoconf
    autoreconf -vif
fi

print_info "运行 configure ..."
./configure

if [ $? -ne 0 ]; then
    print_error "configure 失败。尝试修复 pkg-config 问题..."
    
    # 检查 pkg-config 是否正确安装
    if ! command -v pkg-config &> /dev/null; then
        if [ "$OS" == "Linux" ]; then
            sudo apt install -y pkg-config
        elif [ "$OS" == "Darwin" ]; then
            brew install pkg-config
        fi
    fi
    
    # 再次尝试重新生成和配置
    print_warn "重新运行 autoreconf 和 configure..."
    autoreconf -vif
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig" ./configure
    
    if [ $? -ne 0 ]; then
        print_error "configure 再次失败，请查看错误信息。"
        exit 1
    fi
fi

print_info "编译代码..."
if [ "$OS" == "Darwin" ]; then
    make -j$(sysctl -n hw.ncpu)
else
    make -j$(nproc)
fi

print_step "安装到系统路径 ..."
sudo make install

print_success "验证安装 ..."
audiowmark --version

print_step "🎉 安装完成！audiowmark 已可用。"

# 可选：添加到 PATH
if ! command -v audiowmark &> /dev/null; then
    if [ "$OS" == "Linux" ]; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
        print_info "已添加 /usr/local/bin 到 PATH，请运行 'source ~/.bashrc' 更新当前会话"
    elif [ "$OS" == "Darwin" ]; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
        print_info "已添加 /usr/local/bin 到 PATH，请运行 'source ~/.zshrc' 更新当前会话"
    fi
fi
