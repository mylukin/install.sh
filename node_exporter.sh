#!/bin/bash
set -e

# 1. 获取最新版本号
VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

# 2. 下载并解压
FILENAME="node_exporter-${VERSION}.linux-amd64"
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${FILENAME}.tar.gz"
tar -xzf "${FILENAME}.tar.gz"

# 3. 安装到 /usr/bin
sudo cp "${FILENAME}/node_exporter" /usr/bin/
sudo chown root:root /usr/bin/node_exporter
rm -rf "${FILENAME}"*

# 4. 创建 systemd 服务
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

# 5. 启动服务并设为自启
sudo systemctl daemon-reexec
sudo systemctl enable --now node_exporter

echo "✅ node_exporter ${VERSION} 已成功安装并启动！"
