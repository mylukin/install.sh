#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 脚本用法信息
function show_usage {
    echo -e "${YELLOW}用法: $0 [SDK安装路径] [是否安装模拟器:yes/no]${NC}"
    echo -e "${YELLOW}示例:${NC}"
    echo -e "${YELLOW}  $0                     # 使用默认路径($HOME/Android/Sdk)安装，不安装模拟器${NC}"
    echo -e "${YELLOW}  $0 /custom/path        # 使用自定义路径安装，不安装模拟器${NC}"
    echo -e "${YELLOW}  $0 /custom/path yes    # 使用自定义路径安装，并安装模拟器${NC}"
    echo -e "${YELLOW}  $0 default yes         # 使用默认路径安装，并安装模拟器${NC}"
}

# 解析参数
# 参数1: SDK安装路径（可选，默认为$HOME/Android/Sdk）
# 参数2: 是否安装模拟器（可选，默认为no）

# 设置SDK基础目录
if [ $# -gt 0 ] && [ "$1" != "default" ]; then
    ANDROID_SDK_DIR="$1"
else
    ANDROID_SDK_DIR="$HOME/Android/Sdk"
    echo -e "${YELLOW}使用默认SDK路径: $ANDROID_SDK_DIR${NC}"
fi

# 是否安装模拟器
INSTALL_EMULATOR="no"
if [ $# -gt 1 ]; then
    if [ "$2" = "yes" ]; then
        INSTALL_EMULATOR="yes"
        echo -e "${YELLOW}将安装模拟器和系统镜像${NC}"
    fi
else
    echo -e "${YELLOW}不安装模拟器和系统镜像${NC}"
fi

# 设置环境变量 - ANDROID_HOME, ANDROID_SDK_ROOT 和 ANDROID_NDK_ROOT
echo -e "${YELLOW}设置Android环境变量...${NC}"

# 检查环境变量是否已经存在
if ! grep -q "export ANDROID_HOME=" ~/.bashrc || \
   ! grep -q "export ANDROID_SDK_ROOT=" ~/.bashrc || \
   ! grep -q "export ANDROID_NDK_ROOT=" ~/.bashrc; then
    
    # 添加环境变量到 .bashrc
    echo "export ANDROID_HOME=$ANDROID_SDK_DIR" >> ~/.bashrc
    echo "export ANDROID_SDK_ROOT=$ANDROID_SDK_DIR" >> ~/.bashrc
    echo "export ANDROID_NDK_ROOT=$ANDROID_SDK_DIR/ndk/25.1.8937393" >> ~/.bashrc
    
    # 添加路径到PATH
    echo 'export PATH=$PATH:$ANDROID_HOME/tools' >> ~/.bashrc
    echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
    echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.bashrc
    
    # 重新加载.bashrc
    source ~/.bashrc
    echo -e "${GREEN}环境变量已添加到 ~/.bashrc${NC}"
else
    echo -e "${GREEN}环境变量已存在${NC}"
fi

# 创建Android SDK目录
mkdir -pv "$ANDROID_SDK_DIR"

# 下载和安装Command Line Tools
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
CMDLINE_TOOLS_DIR="$ANDROID_SDK_DIR/cmdline-tools"
if [ ! -d "$CMDLINE_TOOLS_DIR/latest" ]; then
    echo -e "${YELLOW}下载Android Command Line Tools...${NC}"
    curl -L -o cmdline-tools.zip $CMDLINE_TOOLS_URL
    unzip cmdline-tools.zip
    mkdir -pv "$CMDLINE_TOOLS_DIR"
    mv cmdline-tools "$CMDLINE_TOOLS_DIR/latest"
    rm cmdline-tools.zip
    echo -e "${GREEN}Android Command Line Tools已安装${NC}"
else
    echo -e "${GREEN}Android Command Line Tools已存在${NC}"
fi

# 设置当前环境变量以便在此脚本中使用
export ANDROID_HOME=$ANDROID_SDK_DIR
export ANDROID_SDK_ROOT=$ANDROID_SDK_DIR
export ANDROID_NDK_ROOT=$ANDROID_SDK_DIR/ndk/25.1.8937393
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin

# 使用sdkmanager安装必要的SDK组件
if [ -f "$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager" ]; then
    echo -e "${YELLOW}安装Android SDK组件...${NC}"
    
    # 接受许可
    echo -e "${YELLOW}接受SDK许可协议...${NC}"
    yes | "$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager" --licenses > /dev/null
    
    # 安装SDK组件 - 根据参数决定是否安装模拟器
    echo -e "${YELLOW}下载SDK组件 (这可能需要一段时间)...${NC}"
    
    # 基础组件
    "$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager" \
        "platform-tools" \
        "platforms;android-34" \
        "build-tools;34.0.0" \
        "ndk;25.1.8937393"
    
    # 如果需要安装模拟器
    if [ "$INSTALL_EMULATOR" = "yes" ]; then
        echo -e "${YELLOW}安装模拟器和系统镜像...${NC}"
        "$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager" \
            "system-images;android-34;google_apis;x86_64" \
            "emulator"
    fi
    
    echo -e "${GREEN}Android SDK组件已安装${NC}"
else
    echo -e "${RED}未找到sdkmanager，Android SDK安装失败${NC}"
    exit 1
fi

# 检查是否成功安装所需组件
if [ -d "$ANDROID_HOME/platform-tools" ] && \
   [ -d "$ANDROID_HOME/platforms/android-34" ] && \
   [ -d "$ANDROID_HOME/build-tools/34.0.0" ] && \
   [ -d "$ANDROID_HOME/ndk/25.1.8937393" ]; then
    echo -e "${GREEN}Android SDK基础组件安装完成${NC}"
    
    # 如果安装了模拟器，检查模拟器组件
    if [ "$INSTALL_EMULATOR" = "yes" ]; then
        if [ -d "$ANDROID_HOME/emulator" ] && \
           [ -d "$ANDROID_HOME/system-images/android-34/google_apis/x86_64" ]; then
            echo -e "${GREEN}模拟器和系统镜像已成功安装${NC}"
        else
            echo -e "${YELLOW}警告: 模拟器或系统镜像可能安装不完整${NC}"
        fi
    fi
    
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}环境变量设置如下:${NC}"
    echo -e "${GREEN}ANDROID_HOME=$ANDROID_HOME${NC}"
    echo -e "${GREEN}ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT${NC}"
    echo -e "${GREEN}ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "${YELLOW}注意: 请关闭并重新打开终端，或运行 'source ~/.bashrc' 使环境变量生效${NC}"
else
    echo -e "${RED}一些Android SDK组件安装失败，请检查错误信息${NC}"
    exit 1
fi
