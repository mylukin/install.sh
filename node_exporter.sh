#!/bin/bash
set -e

# 检查依赖
command -v curl >/dev/null || { echo "❌ 缺少 curl"; exit 1; }
command -v wget >/dev/null || { echo "❌ 缺少 wget"; exit 1; }

# 1. 获取系统架构
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) PLATFORM="linux-amd64" ;;
  aarch64 | arm64) PLATFORM="linux-arm64" ;;
  *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac

# 2. 获取最新版本号
VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
FILENAME="node_exporter-${VERSION}.${PLATFORM}"

echo "📦 安装版本: v${VERSION}, 架构: ${PLATFORM}"

# 3. 下载并解压
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${FILENAME}.tar.gz"
tar -xzf "${FILENAME}.tar.gz"

# 4. 安装到 /usr/bin
sudo cp "${FILENAME}/node_exporter" /usr/bin/
sudo chown root:root /usr/bin/node_exporter
rm -rf "${FILENAME}"*

# 5. 创建 systemd 服务
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动并设为自启
sudo systemctl daemon-reexec
sudo systemctl enable --now node_exporter

echo "✅ node_exporter v${VERSION} 安装并启动成功"
