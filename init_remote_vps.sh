#!/bin/bash

# 颜色设置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

# 使用说明函数
usage() {
  echo "用法: $0 [选项]"
  echo "选项:"
  echo "  -m MAIN_DOMAIN  : 主域名 (环境变量: MAIN_DOMAIN, 必需)"
  echo "  -a API_DOMAIN   : API 域名 (环境变量: API_DOMAIN, 可选)"
  echo "  -p V2RAY_PORT   : V2Ray 监听端口 (环境变量: V2RAY_PORT, 默认: 666)"
  echo "  -i DNSPOD_ID    : DNSPod ID (环境变量: DP_Id, 必需)"
  echo "  -t DNSPOD_TOKEN : DNSPod Token (环境变量: DP_Key, 必需)"
  echo "  -s, --status    : 显示已安装服务的配置信息"
  echo "  -h, --help      : 显示此帮助信息"
  exit 1
}

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    log_error "此脚本需要root权限运行"
    exit 1
fi

# 检查系统
if [ ! -f /etc/os-release ]; then
    log_error "无法确定操作系统类型"
    exit 1
fi

. /etc/os-release
if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
    log_error "此脚本仅支持Ubuntu和Debian系统，当前系统是: $PRETTY_NAME"
    exit 1
fi

log_info "检测到系统: $PRETTY_NAME"

# 检查和开启BBR
check_and_enable_bbr() {
    log_info "检查BBR拥塞控制算法状态..."
    
    # 检查当前拥塞控制算法
    current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d= -f2 | tr -d ' ')
    available_cc=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | cut -d= -f2)
    
    log_info "当前拥塞控制算法: $current_cc"
    log_info "可用拥塞控制算法: $available_cc"
    
    if echo "$available_cc" | grep -q "bbr"; then
        if [ "$current_cc" = "bbr" ]; then
            log_info "BBR已经启用"
        else
            log_info "BBR可用但未启用，正在启用BBR..."
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
            log_info "BBR已启用"
        fi
    else
        log_warn "当前内核不支持BBR，建议升级内核"
    fi
}

# 显示服务状态和配置信息
show_service_status() {
    log_info "=== 服务状态和配置信息 ==="
    echo
    
    # 检查V2Ray状态
    if systemctl is-active --quiet v2ray 2>/dev/null; then
        log_info "🟢 V2Ray服务状态: 运行中"
        show_v2ray_config
    elif systemctl list-unit-files | grep -q "v2ray"; then
        log_warn "🟡 V2Ray服务状态: 已安装但未运行"
        show_v2ray_config
    else
        log_warn "⚪ V2Ray: 未安装"
    fi
    
    echo
    
    # 检查WireGuard状态
    if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
        log_info "🟢 WireGuard服务状态: 运行中"
        show_wireguard_config
    elif systemctl list-unit-files | grep -q "wg-quick@wg0"; then
        log_warn "🟡 WireGuard服务状态: 已安装但未运行"
        show_wireguard_config
    else
        log_warn "⚪ WireGuard: 未安装"
    fi
    
    echo
    
    # 检查HAProxy状态
    if systemctl is-active --quiet haproxy 2>/dev/null; then
        log_info "🟢 HAProxy服务状态: 运行中"
    elif systemctl list-unit-files | grep -q "haproxy"; then
        log_warn "🟡 HAProxy服务状态: 已安装但未运行"
    else
        log_warn "⚪ HAProxy: 未安装"
    fi
    
    # 检查Nginx状态
    if systemctl is-active --quiet nginx 2>/dev/null; then
        log_info "🟢 Nginx服务状态: 运行中"
    elif systemctl list-unit-files | grep -q "nginx"; then
        log_warn "🟡 Nginx服务状态: 已安装但未运行"
    else
        log_warn "⚪ Nginx: 未安装"
    fi
    
    echo
    log_info "=== 状态检查完成 ==="
}

# 显示V2Ray配置信息
show_v2ray_config() {
    local config_file="/usr/local/etc/v2ray/config.json"
    local main_domain
    
    if [ -f "$config_file" ]; then
        # 从Nginx配置中获取域名
        if [ -f "/etc/nginx/sites-available/default" ]; then
            main_domain=$(grep "server_name" /etc/nginx/sites-available/default | awk '{print $2}' | tr -d ';' | head -1)
        fi
        
        # 如果没有从Nginx获取到，尝试从全局变量获取
        if [ -z "$main_domain" ] && [ -n "$MAIN_DOMAIN" ]; then
            main_domain="$MAIN_DOMAIN"
        fi
        
        # 从配置文件中提取UUID密码
        local uuid_password
        uuid_password=$(grep -A 5 '"clients"' "$config_file" | grep '"password"' | cut -d'"' -f4 | head -1)
        
        if [ -n "$uuid_password" ] && [ -n "$main_domain" ]; then
            echo "┌─────────────────────────────────────────────────────────┐"
            echo "│                    V2Ray Trojan 配置                    │"
            echo "├─────────────────────────────────────────────────────────┤"
            echo "│ 服务器地址: ${main_domain}"
            echo "│ 端口:      443"
            echo "│ 密码:      ${uuid_password}"
            echo "│ 协议:      Trojan"
            echo "│ 传输:      TCP"
            echo "│ TLS:       是"
            echo "│ 跳过证书验证: 否"
            echo "└─────────────────────────────────────────────────────────┘"
            echo
            echo "📱 客户端配置示例:"
            echo "   - 类型: Trojan"
            echo "   - 地址: ${main_domain}"
            echo "   - 端口: 443"
            echo "   - 密码: ${uuid_password}"
            echo "   - SNI: ${main_domain}"
        else
            log_warn "无法读取V2Ray配置信息"
        fi
    else
        log_warn "V2Ray配置文件不存在"
    fi
}

# 显示WireGuard配置信息
show_wireguard_config() {
    local client_config="/root/wireguard-clients/client.conf"
    local server_config="/etc/wireguard/wg0.conf"
    
    if [ -f "$client_config" ]; then
        echo "┌─────────────────────────────────────────────────────────┐"
        echo "│                   WireGuard VPN 配置                    │"
        echo "├─────────────────────────────────────────────────────────┤"
        echo "│ 客户端配置文件: /root/wireguard-clients/client.conf     │"
        echo "│ 服务端IP范围:   10.0.0.1/24                           │"
        echo "│ 客户端IP:       10.0.0.2/24                           │"
        echo "│ 监听端口:       51820                                  │"
        echo "└─────────────────────────────────────────────────────────┘"
        echo
        echo "📋 客户端配置内容:"
        echo "────────────────────────────────────────────────────────────"
        cat "$client_config"
        echo "────────────────────────────────────────────────────────────"
        echo
        echo "📱 使用方法:"
        echo "   1. 下载客户端配置文件: /root/wireguard-clients/client.conf"
        echo "   2. 导入到WireGuard客户端应用"
        echo "   3. 连接即可使用VPN"
    elif [ -f "$server_config" ]; then
        echo "┌─────────────────────────────────────────────────────────┐"
        echo "│                   WireGuard VPN 配置                    │"
        echo "├─────────────────────────────────────────────────────────┤"
        echo "│ 状态: 已安装服务端，但未生成客户端配置                    │"
        echo "│ 服务端配置: /etc/wireguard/wg0.conf                    │"
        echo "│ 监听端口:   51820                                      │"
        echo "└─────────────────────────────────────────────────────────┘"
        echo
        echo "💡 如需生成客户端配置，请重新运行安装脚本"
    else
        log_warn "WireGuard配置文件不存在"
    fi
}

# 显示安装完成后的配置信息汇总
show_installation_summary() {
    echo
    echo "🎉 =============================================== 🎉"
    echo "🎉           安装完成！配置信息汇总               🎉"
    echo "🎉 =============================================== 🎉"
    echo
    
    # 显示V2Ray配置
    if systemctl is-active --quiet v2ray 2>/dev/null; then
        show_v2ray_config
    fi
    
    # 显示WireGuard配置
    if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
        show_wireguard_config
    fi
    
    # 显示管理脚本信息
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│                      管理工具                           │"
    echo "├─────────────────────────────────────────────────────────┤"
    echo "│ 备份脚本:   /root/backup.sh                            │"
    echo "│ 恢复脚本:   /root/restore.sh                           │"
    echo "│ 监控脚本:   /root/monitor.sh                           │"
    echo "│ 查看配置:   $0 --status                        │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo
    echo "🔧 常用命令:"
    echo "   查看服务状态: systemctl status v2ray|nginx|haproxy|wg-quick@wg0"
    echo "   重启服务:     systemctl restart v2ray|nginx|haproxy|wg-quick@wg0"
    echo "   查看日志:     journalctl -u v2ray|nginx|haproxy|wg-quick@wg0 -f"
    echo "   备份配置:     /root/backup.sh"
    echo "   监控检查:     /root/monitor.sh"
    echo
    echo "📞 如有问题，请检查日志或重新运行安装脚本"
    echo "═══════════════════════════════════════════════════════════"
}
get_required_inputs() {
    # 获取主域名
    if [ -z "${MAIN_DOMAIN}" ]; then
        echo -n "请输入主域名: "
        read -r MAIN_DOMAIN
    fi
    
    if [ -z "${MAIN_DOMAIN}" ]; then
        log_error "主域名不能为空"
        exit 1
    fi
    
    # 获取API域名（可选）
    if [ -z "${API_DOMAIN}" ]; then
        echo -n "请输入API域名 (可选，直接回车跳过): "
        read -r API_DOMAIN
    fi
    
    # 获取DNSPod凭据
    if [ -z "${DNSPOD_ID}" ]; then
        echo -n "请输入DNSPod ID: "
        read -r DNSPOD_ID
    fi
    
    if [ -z "${DNSPOD_TOKEN}" ]; then
        echo -n "请输入DNSPod Token: "
        read -r DNSPOD_TOKEN
    fi
    
    if [ -z "${DNSPOD_ID}" ] || [ -z "${DNSPOD_TOKEN}" ]; then
        log_error "DNSPod ID和Token不能为空"
        exit 1
    fi
}

# --- 配置变量优先级: 参数 > 环境变量 > 默认值 ---

# 默认值
DEFAULT_MAIN_DOMAIN=""
DEFAULT_API_DOMAIN=""
DEFAULT_V2RAY_PORT=666

# 从环境变量读取 (如果存在)
MAIN_DOMAIN="${MAIN_DOMAIN:-${DEFAULT_MAIN_DOMAIN}}"
API_DOMAIN="${API_DOMAIN:-${DEFAULT_API_DOMAIN}}"
V2RAY_PORT="${V2RAY_PORT:-${DEFAULT_V2RAY_PORT}}"
DNSPOD_ID="${DP_Id:-}"
DNSPOD_TOKEN="${DP_Key:-}"

# 解析命令行参数 (会覆盖环境变量和默认值)
while getopts ":m:a:p:i:t:sh-:" opt; do
  case ${opt} in
    m ) MAIN_DOMAIN="$OPTARG" ;;
    a ) API_DOMAIN="$OPTARG" ;;
    p ) V2RAY_PORT="$OPTARG" ;;
    i ) DNSPOD_ID="$OPTARG" ;;
    t ) DNSPOD_TOKEN="$OPTARG" ;;
    s ) show_service_status; exit 0 ;;
    h ) usage ;;
    - ) case "${OPTARG}" in
          status) show_service_status; exit 0 ;;
          help) usage ;;
          *) log_error "无效的长选项: --$OPTARG"; usage ;;
        esac ;;
    \\? ) log_error "无效选项: -$OPTARG"; usage ;;
    : ) log_error "选项 -$OPTARG 需要一个参数。"; usage ;;
  esac
done
shift $((OPTIND -1))

# 交互式获取必需的输入
get_required_inputs

# 其他固定变量
SSL_DIR="/etc/ssl"
NGINX_SSL_DIR="/etc/nginx/ssl"

# 安装必要的软件包
install_dependencies() {
    log_info "更新软件包列表..."
    apt update

    log_info "安装基础软件包 (包含 mailutils)..."
    apt install -y curl wget git unzip socat cron ufw mailutils

    # 配置防火墙
    log_info "配置防火墙..."
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
}

# 安装并配置HAProxy
install_haproxy() {
    log_info "安装HAProxy..."
    apt install -y haproxy

    log_info "配置HAProxy..."
    
    # 根据是否配置API_DOMAIN来生成不同的配置
    if [ -n "$API_DOMAIN" ]; then
        # 包含API域名的配置
        cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # 默认SSL配置
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http
    http-reuse safe

frontend https-in
    bind *:443 tfo ssl crt $SSL_DIR/${MAIN_DOMAIN}.pem ssl-min-ver TLSv1.2 ssl-max-ver TLSv1.3
  
    tcp-request inspect-delay 5s
    tcp-request content accept if HTTP

    acl is_oai_host hdr(host) -i ${API_DOMAIN}
    use_backend oai if is_oai_host

    # WebSocket流量判断
    acl is_websocket hdr(Upgrade) -i WebSocket
    use_backend v2ray if is_websocket

    # 将 HTTP 流量发给 web 后端
    use_backend web if HTTP
    # 将其他流量发给 v2ray 后端
    default_backend v2ray

backend web
    server server1 127.0.0.1:80 check

backend v2ray
    acl is_ws hdr(Upgrade) -i WebSocket
    # 如果是 WebSocket 请求，设置必要的头部保持连接
    http-request set-header Connection upgrade if is_ws
    http-request set-header Upgrade WebSocket if is_ws
    server server1 127.0.0.1:${V2RAY_PORT} check
    option forwardfor

backend oai
    server server1 127.0.0.1:8443 ssl verify none
EOF
    else
        # 不包含API域名的配置
        cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # 默认SSL配置
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http
    http-reuse safe

frontend https-in
    bind *:443 tfo ssl crt $SSL_DIR/${MAIN_DOMAIN}.pem ssl-min-ver TLSv1.2 ssl-max-ver TLSv1.3
  
    tcp-request inspect-delay 5s
    tcp-request content accept if HTTP

    # WebSocket流量判断
    acl is_websocket hdr(Upgrade) -i WebSocket
    use_backend v2ray if is_websocket

    # 将 HTTP 流量发给 web 后端
    use_backend web if HTTP
    # 将其他流量发给 v2ray 后端
    default_backend v2ray

backend web
    server server1 127.0.0.1:80 check

backend v2ray
    acl is_ws hdr(Upgrade) -i WebSocket
    # 如果是 WebSocket 请求，设置必要的头部保持连接
    http-request set-header Connection upgrade if is_ws
    http-request set-header Upgrade WebSocket if is_ws
    server server1 127.0.0.1:${V2RAY_PORT} check
    option forwardfor
EOF
    fi

    log_info "启动HAProxy..."
    
    # 检查SSL证书是否存在
    if [ ! -f "${SSL_DIR}/${MAIN_DOMAIN}.pem" ]; then
        log_error "SSL证书文件不存在: ${SSL_DIR}/${MAIN_DOMAIN}.pem"
        log_error "请确保acme.sh已正确生成证书"
        exit 1
    fi
    
    # 检查后端服务是否运行
    if ! systemctl is-active --quiet v2ray; then
        log_error "V2Ray服务未运行，HAProxy无法启动"
        exit 1
    fi
    
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx服务未运行，HAProxy无法启动"
        exit 1
    fi
    
    systemctl enable haproxy
    systemctl restart haproxy
    
    if systemctl is-active --quiet haproxy; then
        log_info "HAProxy启动成功"
    else
        log_error "HAProxy启动失败，请检查配置和依赖服务"
        exit 1
    fi
}

# 安装并配置V2Ray
install_v2ray() {
    log_info "安装V2Ray..."
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    # 创建日志目录
    mkdir -p /var/log/v2ray
    
    # 生成随机UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    
    log_info "配置V2Ray..."
    cat > /usr/local/etc/v2ray/config.json << EOF
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "protocol": "trojan",
      "listen": "127.0.0.1",
      "port": ${V2RAY_PORT},
      "settings": {
        "clients": [
          {
            "password": "${UUID}",
            "level": 0
          }
        ],
        "fallbacks": [
          {
            "dest": 80
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": ["bittorrent"]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": ["0.0.0.0/0"]
      }
    ]
  },
  "dns": {
    "servers": ["1.1.1.1", "8.8.8.8"]
  }
}
EOF

    log_info "启动V2Ray..."
    systemctl enable v2ray
    systemctl restart v2ray
    
    # 检查V2Ray是否启动成功
    if systemctl is-active --quiet v2ray; then
        log_info "V2Ray启动成功"
        
        # 保存配置信息到文件供后续查看
        cat > /root/v2ray-info.txt << EOF
V2Ray Trojan配置信息:
服务器: ${MAIN_DOMAIN}
端口: 443
密码: ${UUID}
协议: Trojan
EOF
        log_info "V2Ray配置信息已保存到 /root/v2ray-info.txt"
    else
        log_error "V2Ray启动失败"
        exit 1
    fi
}

# 安装并配置Nginx
install_nginx() {
    log_info "安装Nginx..."
    apt install -y nginx
    
    # 创建证书目录
    mkdir -p ${NGINX_SSL_DIR}
    
    log_info "配置默认网站..."
    cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm;
    
    server_name ${MAIN_DOMAIN};
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    # 下载网页文件
    log_info "下载网页文件..."
    local html_target_dir="/var/www/html"
    mkdir -p "$html_target_dir"

    # 下载 index.html
    if curl -s -o "$html_target_dir/index.html" "https://raw.githubusercontent.com/mylukin/install.sh/refs/heads/main/index.html"; then
        log_info "成功下载 index.html"
    else
        log_warn "下载 index.html 失败，将使用 Nginx 默认页面。"
    fi

    # 下载 logo.jpg
    if curl -s -o "$html_target_dir/logo.jpg" "https://raw.githubusercontent.com/mylukin/install.sh/refs/heads/main/logo.jpg"; then
        log_info "成功下载 logo.jpg"
    else
        log_warn "下载 logo.jpg 失败。"
    fi

    # 设置正确的权限
    log_info "设置网页文件权限..."
    chown -R www-data:www-data "$html_target_dir"
    chmod -R 755 "$html_target_dir"

    # 只有在API_DOMAIN不为空时才配置OpenAI API代理
    if [ -n "$API_DOMAIN" ]; then
        log_info "配置OpenAI API代理..."
        cat > /etc/nginx/sites-available/openai.api << EOF
server {
    listen 8443 ssl;
    server_name ${API_DOMAIN};
    ssl_certificate ${NGINX_SSL_DIR}/${MAIN_DOMAIN};
    ssl_certificate_key ${NGINX_SSL_DIR}/${MAIN_DOMAIN}.key;
    
    location / {
        proxy_pass https://api.openai.com;
        proxy_ssl_server_name on;
        proxy_set_header Host api.openai.com;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/openai.api /etc/nginx/sites-enabled/
    fi
    
    log_info "启动Nginx..."
    systemctl enable nginx
    systemctl restart nginx
    
    # 检查Nginx是否启动成功
    if systemctl is-active --quiet nginx; then
        log_info "Nginx启动成功"
    else
        log_error "Nginx启动失败"
        exit 1
    fi
}

# 安装并配置acme.sh
install_acme() {
    log_info "安装acme.sh..."
    # 使用主域名的 admin 邮箱注册 acme.sh
    curl https://get.acme.sh | sh -s email=admin@${MAIN_DOMAIN}

    # 设置DNSPod API凭据 (已从参数或环境变量获取)
    log_info "配置acme.sh使用DNSPod API..."
    export DP_Id="${DNSPOD_ID}"
    export DP_Key="${DNSPOD_TOKEN}"

    # 根据API_DOMAIN是否存在决定申请证书的域名
    if [ -n "$API_DOMAIN" ]; then
        log_info "申请SSL证书 for ${MAIN_DOMAIN} and ${API_DOMAIN}..."
        ~/.acme.sh/acme.sh --issue --dns dns_dp -d "${MAIN_DOMAIN}" -d "${API_DOMAIN}" --server letsencrypt
    else
        log_info "申请SSL证书 for ${MAIN_DOMAIN}..."
        ~/.acme.sh/acme.sh --issue --dns dns_dp -d "${MAIN_DOMAIN}" --server letsencrypt
    fi

    if [ $? -ne 0 ]; then
        log_error "SSL证书申请失败. 请检查DNSPod API凭据和域名解析设置。"
        exit 1
    fi

    log_info "安装证书..."
    mkdir -p ${SSL_DIR}
    mkdir -p ${NGINX_SSL_DIR}
    
    # 安装到HAProxy
    ~/.acme.sh/acme.sh --install-cert -d ${MAIN_DOMAIN} \
      --key-file ${SSL_DIR}/${MAIN_DOMAIN}.key \
      --fullchain-file ${SSL_DIR}/${MAIN_DOMAIN}.crt \
      --reloadcmd "cat ${SSL_DIR}/${MAIN_DOMAIN}.crt ${SSL_DIR}/${MAIN_DOMAIN}.key > ${SSL_DIR}/${MAIN_DOMAIN}.pem && systemctl restart haproxy"
    
    # 生成HAProxy所需的合并证书文件
    if [ -f "${SSL_DIR}/${MAIN_DOMAIN}.crt" ] && [ -f "${SSL_DIR}/${MAIN_DOMAIN}.key" ]; then
        cat ${SSL_DIR}/${MAIN_DOMAIN}.crt ${SSL_DIR}/${MAIN_DOMAIN}.key > ${SSL_DIR}/${MAIN_DOMAIN}.pem
        log_info "HAProxy证书文件已生成: ${SSL_DIR}/${MAIN_DOMAIN}.pem"
    else
        log_error "证书文件生成失败"
        exit 1
    fi
    
    # 安装到Nginx目录
    ln -sf ${SSL_DIR}/${MAIN_DOMAIN}.crt ${NGINX_SSL_DIR}/${MAIN_DOMAIN}
    ln -sf ${SSL_DIR}/${MAIN_DOMAIN}.key ${NGINX_SSL_DIR}/${MAIN_DOMAIN}.key
    
    log_info "配置证书自动更新..."
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade

    # 设置每日运行
    echo "0 6 * * * root ~/.acme.sh/acme.sh --cron --home \"/root/.acme.sh\" > /dev/null && /root/monitor.sh >> /var/log/monitor.log 2>&1" > /etc/cron.d/service-monitor
}

# 安装WireGuard
install_wireguard() {
    echo -n "是否要安装WireGuard VPN? (y/n): "
    read -r install_wg
    
    if [[ ! $install_wg =~ ^[Yy]$ ]]; then
        log_info "跳过WireGuard安装"
        return 0
    fi
    
    log_info "安装WireGuard..."
    apt install -y wireguard
    
    # 生成WireGuard密钥
    wg_private_key=$(wg genkey)
    wg_public_key=$(echo "$wg_private_key" | wg pubkey)
    client_private_key=$(wg genkey)
    client_public_key=$(echo "$client_private_key" | wg pubkey)
    
    # 配置WireGuard服务器
    log_info "配置WireGuard服务器..."
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = ${wg_private_key}
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = ${client_public_key}
AllowedIPs = 10.0.0.2/32
EOF

    # 启用IP转发
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf
    
    # 开启防火墙端口
    ufw allow 51820/udp
    
    # 启动WireGuard
    log_info "启动WireGuard..."
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    echo -n "是否要生成WireGuard客户端配置? (y/n): "
    read -r generate_client
    
    if [[ $generate_client =~ ^[Yy]$ ]]; then
        # 生成客户端配置
        SERVER_IP=$(curl -s http://ipinfo.io/ip)
        log_info "生成WireGuard客户端配置..."
        mkdir -p /root/wireguard-clients
        cat > /root/wireguard-clients/client.conf << EOF
[Interface]
PrivateKey = ${client_private_key}
Address = 10.0.0.2/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = ${wg_public_key}
Endpoint = ${SERVER_IP}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

        log_info "WireGuard客户端配置已生成"
        
        # 保存WireGuard信息
        cat > /root/wireguard-info.txt << EOF
WireGuard VPN配置信息:
服务端IP: ${SERVER_IP}
监听端口: 51820
服务端内网IP: 10.0.0.1/24
客户端内网IP: 10.0.0.2/24
客户端配置文件: /root/wireguard-clients/client.conf
EOF
        log_info "WireGuard配置信息已保存到 /root/wireguard-info.txt"
    else
        log_info "跳过客户端配置生成"
    fi
}

# 创建备份和恢复脚本
create_backup_scripts() {
    log_info "创建备份脚本..."
    cat > /root/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/server_backup_${TIMESTAMP}.tar.gz"

mkdir -p ${BACKUP_DIR}

echo "正在备份配置文件..."
tar -czf ${BACKUP_FILE} \
    /etc/haproxy/haproxy.cfg \
    /usr/local/etc/v2ray/config.json \
    /etc/nginx/sites-available \
    /etc/wireguard \
    /root/wireguard-clients \
    ${SSL_DIR} 2>/dev/null

echo "备份完成: ${BACKUP_FILE}"
EOF

    cat > /root/restore.sh << 'EOF'
#!/bin/bash
if [ $# -ne 1 ]; then
    echo "用法: $0 <备份文件路径>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "错误: 备份文件不存在"
    exit 1
fi

echo "正在恢复配置文件..."
tar -xzf "$1" -C /

echo "重启服务..."
systemctl restart haproxy
systemctl restart v2ray
systemctl restart nginx
if systemctl is-enabled wg-quick@wg0 >/dev/null 2>&1; then
    systemctl restart wg-quick@wg0
fi

echo "恢复完成"
EOF

    chmod +x /root/backup.sh
    chmod +x /root/restore.sh
    
    # 创建每周自动备份
    echo "0 0 * * 0 root /root/backup.sh > /dev/null 2>&1" > /etc/cron.d/auto-backup
}

# 服务状态监控脚本
create_monitor_script() {
    log_info "创建服务监控脚本..."
    
    # 根据是否安装WireGuard来决定监控的服务
    SERVICES_LIST="\"haproxy\" \"v2ray\" \"nginx\""
    if systemctl is-enabled wg-quick@wg0 >/dev/null 2>&1; then
        SERVICES_LIST="\"haproxy\" \"v2ray\" \"nginx\" \"wg-quick@wg0\""
    fi
    
    cat > /root/monitor.sh << EOF
#!/bin/bash
SERVICES=(${SERVICES_LIST})
EMAIL="mylukin@gmail.com"  # 使用您的邮箱地址

echo "服务状态检查开始于 \$(date)"
echo "======================="

for SERVICE in "\${SERVICES[@]}"; do
    if systemctl is-active --quiet \${SERVICE}; then
        echo "✅ \${SERVICE} 正在运行"
    else
        echo "❌ \${SERVICE} 已停止，尝试重启..."
        systemctl restart \${SERVICE}
        if systemctl is-active --quiet \${SERVICE}; then
            echo "  ✅ \${SERVICE} 已成功重启"
        else
            echo "  ❌ \${SERVICE} 重启失败"
            echo "服务 \${SERVICE} 故障，请检查" | mail -s "服务器警报: \${SERVICE} 故障" \${EMAIL}
        fi
    fi
done

echo "证书到期检查..."
DOMAIN="${MAIN_DOMAIN}"
CERT_END_DATE=\$(openssl x509 -enddate -noout -in ${SSL_DIR}/\${DOMAIN}.crt 2>/dev/null | cut -d= -f2)
if [ -n "\$CERT_END_DATE" ]; then
    CERT_END_EPOCH=\$(date -d "\${CERT_END_DATE}" +%s)
    NOW_EPOCH=\$(date +%s)
    DAYS_LEFT=\$(( (CERT_END_EPOCH - NOW_EPOCH) / 86400 ))

    echo "SSL证书剩余有效期: \${DAYS_LEFT} 天"
    if [ \${DAYS_LEFT} -lt 15 ]; then
        echo "⚠️ 证书即将过期，尝试更新..."
        /root/.acme.sh/acme.sh --cron --home "/root/.acme.sh"
    fi
else
    echo "⚠️ 无法检查证书状态"
fi

echo "======================="
echo "检查完成于 \$(date)"
EOF

    chmod +x /root/monitor.sh
}

# 主安装流程
main() {
    log_info "开始安装流程..."
    log_info "安装顺序: 基础依赖 -> 后端服务(V2Ray/Nginx) -> SSL证书 -> 前端代理(HAProxy) -> 可选组件"
    
    # 检查和开启BBR
    check_and_enable_bbr
    
    # 安装基础依赖
    install_dependencies
    
    # 安装后端服务
    install_v2ray
    install_nginx
    
    # 申请SSL证书
    install_acme
    
    # 安装前端代理 (依赖证书和后端服务)
    install_haproxy
    
    # 可选组件
    install_wireguard
    create_backup_scripts
    create_monitor_script
    
    # 显示安装完成后的配置信息汇总
    show_installation_summary
}

# 执行主流程
main