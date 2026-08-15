#!/bin/bash

set +e

# ====================================
#     CXLVIN MULTIPLEX DEPLOYER v1.3
# ====================================

# =========================
# COLORS
# =========================
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# =========================
# DEPLOYMENT HISTORY FILE
# =========================
HISTORY_FILE="$HOME/.cxlvin_deploy_history"
touch "$HISTORY_FILE"

# =========================
#  TIME FUNCTION
# =========================
time_ago() {
    local SEC=$1
    if [ "$SEC" -lt 60 ]; then
        echo "${SEC} sec ago"
    elif [ "$SEC" -lt 3600 ]; then
        echo "$((SEC / 60)) min $((SEC % 60)) sec ago"
    elif [ "$SEC" -lt 86400 ]; then
        echo "$((SEC / 3600)) hr $(((SEC % 3600) / 60)) min ago"
    else
        echo "$((SEC / 86400)) days ago"
    fi
}

while true; do

# =========================
# VARIABLES
# =========================
PROJECT_ID="$(gcloud config get-value project)"
RAND=$(openssl rand -hex 3)
CLOUD_RUN_SERVICE_NAME="cxlvin-$RAND"
DOMAIN="betatest-v1-3.d4em0n35.workers.dev"
BUILD_DIR=$(mktemp -d)
DEPLOY_TIMESTAMP=$(date +%s)  

# =========================
# CLEANUP
# =========================
cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

# =========================
# HEADER
# =========================
clear
echo ""
echo -e "${CYAN}==============================================${NC}"
echo -e "${GREEN}        CXLVIN MULTIPLEX DEPLOYER v1.3${NC}"
echo -e "${CYAN}==============================================${NC}"

# =========================
# HISTORY DISPLAY
# =========================
echo ""
echo -e "${YELLOW}   YOUR DEPLOYED SERVER HOSTS 🌩️${NC}"
echo -e "${CYAN}--------------------------------------------------------${NC}"
if [ -s "$HISTORY_FILE" ]; then
    CURRENT_TIME=$(date +%s)
    echo -e "${WHITE}No.  Region               Deployed        URL${NC}"
    echo -e "${WHITE}--------------------------------------------------------${NC}"
    COUNT=1
    tac "$HISTORY_FILE" | while IFS='|' read -r H_TIME H_REGION H_URL; do
        AGO=$((CURRENT_TIME - H_TIME))
        printf "${GREEN}%-2s)${NC} %-22s %-15s %s\n" "$COUNT" "$H_REGION" "$(time_ago $AGO)" "$H_URL"
        ((COUNT++))
    done
else
    echo -e "${WHITE}No previous deployments yet ¯⁠\⁠_⁠(⁠ツ⁠)⁠_⁠/⁠¯${NC}"
fi
echo ""

# =========================
# CHECK PROJECT
# =========================
if [ -z "$PROJECT_ID" ]; then
    echo ""
    echo -e "${RED}ERROR: No Google Cloud project set.${NC}"
    echo ""
    echo "Run: gcloud config set project YOUR_PROJECT_ID"
    echo ""
    exit 1
fi

# =========================================
#  REGION LIST 
# =========================================
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}        SELECT REGION 🌏${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${YELLOW}NOTE:${NC} Please select only regions available in 
your Google Cloud environment to ensure a smooth and successful build."
echo ""
echo "0) us-central1 (Iowa, USA)"
echo "1) asia-southeast1 (Singapore)"
echo "2) asia-east1 (Taiwan)"
echo "3) asia-southeast3 (Thailand)"
echo "4) us-west1 (Oregon, USA)"
echo ""

while true; do
    read -p "Select Region [0-4]: " REGION_CHOICE
    case "$REGION_CHOICE" in
        0) REGION="us-central1"; REGION_DISPLAY="us-central1 (Iowa, USA)"; break ;;
        1) REGION="asia-southeast1"; REGION_DISPLAY="asia-southeast1 (Singapore)"; break ;;
        2) REGION="asia-east1"; REGION_DISPLAY="asia-east1 (Taiwan)"; break ;;
        3) REGION="asia-southeast3"; REGION_DISPLAY="asia-southeast3 (Thailand)"; break ;;
        4) REGION="us-west1"; REGION_DISPLAY="us-west1 (Oregon, USA)"; break ;;
        *) echo ""; echo -e "${RED}⚠ PLEASE CHOOSE ONLY 0-4${NC}"; echo "" ;;
    esac
done

echo ""
echo -e "${GREEN}Selected Region: ${WHITE}$REGION_DISPLAY${NC}"
echo ""

# =========================
# ENABLE REQUIRED APIS
# =========================
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}        ENABLING REQUIRED APIS${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

gcloud services enable \
run.googleapis.com \
cloudbuild.googleapis.com \
artifactregistry.googleapis.com --quiet

# =========================
# MAIN CHOICE: AUTO OR MANUAL ONLY
# =========================
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}        BUILD MODE SELECTION${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo "1) AUTO BUILD CONFIGURATION"
echo "2) MANUAL BUILD CONFIGURATION"
echo ""

while true; do
    read -p "Select Option [1-2]: " MAIN_CHOICE
    case "$MAIN_CHOICE" in
        1) BUILD_MODE="AUTO"; echo ""; echo -e "${GREEN}SELECTED: AUTO BUILD${NC}"; break ;;
        2) BUILD_MODE="MANUAL"; echo ""; echo -e "${GREEN}SELECTED: MANUAL CONFIGURATION${NC}"; break ;;
        *) echo ""; echo -e "${RED}⚠ PLEASE CHOOSE ONLY 1 OR 2${NC}"; echo "" ;;
    esac
done

# =========================
# AUTO BUILD: SHOW 3 PRESETS
# =========================
if [ "$BUILD_MODE" = "AUTO" ]; then
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}        AUTO BUILD PRESETS 🤖${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo "1) 🚀 HIGH PERFORMANCE"
echo "   Billing Type        : Instance-Based"
echo "   vCPU                : 4CPU"
echo "   Memory              : 4Gi"
echo "   Concurrency         : 1000"
echo "   Timeout             : 3600"
echo "   Auto Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 4"
echo "   Revision Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 4"
echo "   Execution Env       : Gen2"
echo "   CPU Boost           : Enabled"
echo ""
echo "2) 🌱 ESSENTIAL"
echo "   Billing Type        : Instance-Based"
echo "   vCPU                : 1CPU"
echo "   Memory              : 512Mi"
echo "   Concurrency         : 1000"
echo "   Timeout             : 3600"
echo "   Auto Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 2"
echo "   Revision Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 2"
echo "   Execution Env       : Gen2"
echo "   CPU Boost           : Enabled"
echo ""
echo "3) ⚖️ STANDARD"
echo "   Billing Type        : Instance-Based"
echo "   vCPU                : 1CPU"
echo "   Memory              : 1Gi"
echo "   Concurrency         : 1000"
echo "   Timeout             : 3600"
echo "   Auto Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 2"
echo "   Revision Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 2"
echo "   Execution Env       : Gen2"
echo "   CPU Boost           : Enabled"
echo ""
echo "4) ⚡ BALANCED"
echo "   Billing Type        : Instance-Based"
echo "   vCPU                : 2CPU"
echo "   Memory              : 2Gi"
echo "   Concurrency         : 1000"
echo "   Timeout             : 3600"
echo "   Auto Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 2"
echo "   Revision Scaling:"
echo "     Min Instances       : 1"
echo "     Max Instances       : 2"
echo "   Execution Env       : Gen2"
echo "   CPU Boost           : Enabled"
echo ""

while true; do
    read -p "Select Preset [1-4]: " AUTO_PRESET
    case "$AUTO_PRESET" in
        1) BILLING_MODE="instance"; MEMORY="4Gi"; CPU="4"; CONCURRENCY="1000"; TIMEOUT="3600"; MIN_INST="1"; MAX_INST="4"; EXEC_ENV="gen2"; CPU_BOOST="yes"
           echo ""; echo -e "${GREEN}APPLIED: HIGH PERFORMANCE${NC}"; break ;;
        2) BILLING_MODE="instance"; MEMORY="512Mi"; CPU="1"; CONCURRENCY="1000"; TIMEOUT="3600"; MIN_INST="1"; MAX_INST="2"; EXEC_ENV="gen2"; CPU_BOOST="yes"
           echo ""; echo -e "${GREEN}APPLIED: ESSENTIAL${NC}"; break ;;
        3) BILLING_MODE="instance"; MEMORY="1Gi"; CPU="1"; CONCURRENCY="1000"; TIMEOUT="3600"; MIN_INST="1"; MAX_INST="2"; EXEC_ENV="gen2"; CPU_BOOST="yes"
           echo ""; echo -e "${GREEN}APPLIED: STANDARD${NC}"; break ;;
        4) BILLING_MODE="instance"; MEMORY="2Gi"; CPU="2"; CONCURRENCY="1000"; TIMEOUT="3600"; MIN_INST="1"; MAX_INST="2"; EXEC_ENV="gen2"; CPU_BOOST="yes"
           echo ""; echo -e "${GREEN}APPLIED: BALANCED${NC}"; break ;;
        *) echo ""; echo -e "${RED}⚠ PLEASE CHOOSE ONLY 1, 2, 3 OR 4${NC}"; echo "" ;;
    esac
done
fi

# =========================
# MANUAL CONFIGURATION - FULL SETUP
# =========================
if [ "$BUILD_MODE" = "MANUAL" ]; then
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}      MANUAL RESOURCE SETTINGS 🧩${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Fixed Defaults:${NC}"
echo "  Concurrency         : 1000"
echo "  Timeout             : 3600"
echo "  Execution Env       : Gen2"
echo "  CPU Boost           : Enabled"
echo ""

while true; do
    echo "1) REQUEST-BASED (CPU THROTTLING)"
    echo "2) INSTANCE-BASED (FULL CPU)"
    echo ""
    read -p "Select Billing Type [1-2]: " BILLING_CHOICE
    case "$BILLING_CHOICE" in
        1) BILLING_MODE="request"; break ;;
        2) BILLING_MODE="instance"; break ;;
        *) echo ""; echo -e "${RED}⚠ PLEASE CHOOSE 1 OR 2${NC}"; echo "" ;;
    esac
done

echo ""
echo "MEMORY                vCPU"
echo "1) 512Mi              1) 1CPU"
echo "2) 1Gi                2) 2CPU"
echo "3) 2Gi                3) 4CPU"
echo "4) 4Gi                4) 6CPU"
echo "5) 8Gi                5) 8CPU"
echo "6) 16Gi"
echo "7) 32Gi"
echo ""

while true; do
    read -p "Select Memory [1-7]: " MEMORY_CHOICE
    case "$MEMORY_CHOICE" in
        1) MEMORY="512Mi"; break ;;
        2) MEMORY="1Gi"; break ;;
        3) MEMORY="2Gi"; break ;;
        4) MEMORY="4Gi"; break ;;
        5) MEMORY="8Gi"; break ;;
        6) MEMORY="16Gi"; break ;;
        7) MEMORY="32Gi"; break ;;
        *) echo ""; echo -e "${RED}⚠ PLEASE CHOOSE 1-7${NC}"; echo "" ;;
    esac
done

while true; do
    read -p "Select vCPU [1-5]: " CPU_CHOICE
    case "$CPU_CHOICE" in
        1) CPU="1"; break ;;
        2) CPU="2"; break ;;
        3) CPU="4"; break ;;
        4) CPU="6"; break ;;
        5) CPU="8"; break ;;
        *) echo ""; echo -e "${RED}⚠ PLEASE CHOOSE 1-5${NC}"; echo "" ;;
    esac
done

# --------------------------
#  CORRECTED SCALING RULES
# --------------------------
echo ""
if [ "$MEMORY" = "4Gi" ] && [ "$CPU" = "4" ]; then
    echo -e "${YELLOW} SPECIAL BUILD: 4Gi + 4vCPU${NC}"
    echo "Allowed: Min = 0,1 | Max = 0,1,2,3,4"
    while true; do
        read -p "Enter Min Instances [0 or 1]: " MIN_INST
        case "$MIN_INST" in
            0|1) break ;;
            *) echo ""; echo -e "${RED}⚠ MINIMUM CAN ONLY BE 0 OR 1${NC}"; echo "" ;;
        esac
    done
    while true; do
        read -p "Enter Max Instances [0,1,2,3,4]: " MAX_INST
        case "$MAX_INST" in
            0|1|2|3|4) break ;;
            *) echo ""; echo -e "${RED}⚠ MAXIMUM CAN ONLY BE 0,1,2,3,4${NC}"; echo "" ;;
        esac
    done
else
    echo -e "${YELLOW} DEFAULT BUILD${NC}"
    echo "Allowed: Min = 0,1 | Max = 0,1,2"
    while true; do
        read -p "Enter Min Instances [0 or 1]: " MIN_INST
        case "$MIN_INST" in
            0|1) break ;;
            *) echo ""; echo -e "${RED}⚠ MINIMUM CAN ONLY BE 0 OR 1${NC}"; echo "" ;;
        esac
    done
    while true; do
        read -p "Enter Max Instances [0,1,2]: " MAX_INST
        case "$MAX_INST" in
            0|1|2) break ;;
            *) echo ""; echo -e "${RED}⚠ MAXIMUM CAN ONLY BE 0,1,2${NC}"; echo "" ;;
        esac
    done
fi

CONCURRENCY="1000"
TIMEOUT="3600"
EXEC_ENV="gen2"
CPU_BOOST="yes"
fi

# ==================================================
# CONFIG.JSON 12 PROTOCOLS 
# ==================================================

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || exit 1

cat > config.json <<'EOF'
{
  "log": {"loglevel": "warning"},
  "dns": {
    "servers": ["1.1.1.1", "223.5.5.5", "8.8.8.8"],
    "queryStrategy": "UseIP",
    "disableCache": false,
    "disableFallback": false,
    "hosts": {
      "doubleclick.net": "127.0.0.1",
      "dns.adguard-dns.com": "127.0.0.1",
      "googlesyndication.com": "127.0.0.1",
      "googleadservices.com": "127.0.0.1"
    }
  },
  "inbounds": [
    {
      "port": 10001, "listen": "::", "protocol": "trojan", "tag": "trojan-ws",
      "settings": {"clients": [{"password": "Cxlvin777"}]},
      "streamSettings": {
        "network": "ws", "wsSettings": {"path": "/CxlvinTRWS"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10002, "listen": "::", "protocol": "vless", "tag": "vless-ws",
      "settings": {"clients": [{"id": "cxlvin777"}], "decryption": "none"},
      "streamSettings": {
        "network": "ws", "wsSettings": {"path": "/CxlvinVlWS"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10003, "listen": "::", "protocol": "shadowsocks", "tag": "shadowsocks-ws",
      "settings": {"clients": [{"password": "Cxlvin777", "method": "chacha20-ietf-poly1305"}]},
      "streamSettings": {
        "network": "ws", "wsSettings": {"path": "/CxlvinSSWS"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10004, "listen": "::", "protocol": "vmess", "tag": "vmess-ws",
      "settings": {"clients": [{"id": "cxlvin777", "alterId": 0, "security": "auto"}]},
      "streamSettings": {
        "network": "ws", "wsSettings": {"path": "/CxlvinVMWS"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 11001, "listen": "::", "protocol": "trojan", "tag": "trojan-hu",
      "settings": {"clients": [{"password": "Cxlvin777"}]},
      "streamSettings": {
        "network": "httpupgrade", "httpupgradeSettings": {"path": "/CxlvinTRHU"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 11002, "listen": "::", "protocol": "vless", "tag": "vless-hu",
      "settings": {"clients": [{"id": "cxlvin777"}], "decryption": "none"},
      "streamSettings": {
        "network": "httpupgrade", "httpupgradeSettings": {"path": "/CxlvinVlHU"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 11003, "listen": "::", "protocol": "shadowsocks", "tag": "shadowsocks-hu",
      "settings": {"clients": [{"password": "Cxlvin777", "method": "chacha20-ietf-poly1305"}]},
      "streamSettings": {
        "network": "httpupgrade", "httpupgradeSettings": {"path": "/CxlvinSSHU"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 11004, "listen": "::", "protocol": "vmess", "tag": "vmess-hu",
      "settings": {"clients": [{"id": "cxlvin777", "alterId": 0, "security": "auto"}]},
      "streamSettings": {
        "network": "httpupgrade", "httpupgradeSettings": {"path": "/CxlvinVMHU"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10010, "listen": "::", "protocol": "trojan", "tag": "trojan-xh",
      "settings": {"clients": [{"password": "Cxlvin777"}]},
      "streamSettings": {
        "network": "xhttp", "xhttpSettings": {"path": "/CxlvinTRXH", "mode": "auto"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10009, "listen": "::", "protocol": "vless", "tag": "vless-xh",
      "settings": {"clients": [{"id": "cxlvin777"}], "decryption": "none"},
      "streamSettings": {
        "network": "xhttp", "xhttpSettings": {"path": "/CxlvinVlXH", "mode": "auto"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10012, "listen": "::", "protocol": "shadowsocks", "tag": "shadowsocks-xh",
      "settings": {"clients": [{"password": "Cxlvin777", "method": "chacha20-ietf-poly1305"}]},
      "streamSettings": {
        "network": "xhttp", "xhttpSettings": {"path": "/CxlvinSSXH", "mode": "auto"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    },
    {
      "port": 10011, "listen": "::", "protocol": "vmess", "tag": "vmess-xh",
      "settings": {"clients": [{"id": "cxlvin777", "alterId": 0, "security": "auto"}]},
      "streamSettings": {
        "network": "xhttp", "xhttpSettings": {"path": "/CxlvinVMXH", "mode": "auto"},
        "sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "fakedns"]}
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom", "tag": "direct",
      "settings": {"domainStrategy": "AsIs"},
      "streamSettings": {"sockopt": {"tcpFastOpen": true, "tcpNoDelay": true, "tcpKeepAliveInterval": 15, "tcpKeepAliveIdle": 30, "tcpKeepAliveCount": 3, "tcpQuickAck": true, "tcpcongestion": "bbr"}}
    },
    {"protocol": "blackhole", "tag": "block"}
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [{"type": "field", "inboundTag": ["trojan-ws","vless-ws","shadowsocks-ws","vmess-ws","trojan-hu","vless-hu","shadowsocks-hu","vmess-hu","trojan-xh","vless-xh","shadowsocks-xh","vmess-xh"], "outboundTag": "direct"}]
  }
}
EOF

# =========================
#   NGINX.CONF
# =========================

cat > nginx.conf <<'EOF'
worker_processes auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 1048576;

events {
    worker_connections 161072;
    multi_accept on;
    use epoll;
}

http {
    http2_max_concurrent_streams 1024;

    include /usr/local/openresty/nginx/conf/mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 120;
    keepalive_requests 100000;
    reset_timedout_connection on;

    client_max_body_size 0;
    client_body_timeout 60;
    client_header_timeout 60;
    send_timeout 3600;

    server_tokens off;

    resolver 1.1.1.1 223.5.5.5 8.8.8.8 valid=86400s;
    resolver_timeout 1s;

    proxy_connect_timeout 10;
    proxy_send_timeout 3600;
    proxy_read_timeout 3600;
    proxy_socket_keepalive on;
    proxy_buffering off;
    proxy_request_buffering off;
    chunked_transfer_encoding off;
    proxy_ssl_session_reuse on;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    upstream trojan_ws       { server [::1]:10001; keepalive 512; }
    upstream vless_ws        { server [::1]:10002; keepalive 512; }
    upstream shadowsocks_ws  { server [::1]:10003; keepalive 512; }
    upstream vmess_ws        { server [::1]:10004; keepalive 512; }

    upstream trojan_hu       { server [::1]:11001; keepalive 512; }
    upstream vless_hu        { server [::1]:11002; keepalive 512; }
    upstream shadowsocks_hu  { server [::1]:11003; keepalive 512; }
    upstream vmess_hu        { server [::1]:11004; keepalive 512; }

    server {
        listen 8080 default_server reuseport backlog=65535;
        listen [::]:8080 default_server reuseport backlog=65535;
        server_name _;
        http2 on;

        location /health {
            access_log off;
            default_type text/plain;
            return 200 "OK\n";
        }

        location / {
            proxy_ssl_server_name on;
            proxy_ssl_protocols TLSv1.2 TLSv1.3;
            proxy_pass https://betatest-v1-3.d4em0n35.workers.dev;
            proxy_set_header Host betatest-v1-3.d4em0n35.workers.dev;
            proxy_set_header Referer https://www.google.com/;
            proxy_set_header Origin https://www.cloudflare.com/;
            proxy_set_header Connection "";
            proxy_http_version 1.1;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location ^~ /CxlvinTRWS {
            proxy_pass http://trojan_ws;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinVlWS {
            proxy_pass http://vless_ws;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_buffering off;
            proxy_request_buffering off;
            chunked_transfer_encoding off;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinSSWS {
            proxy_pass http://shadowsocks_ws;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinVMWS {
            proxy_pass http://vmess_ws;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }

        location ^~ /CxlvinTRHU {
            proxy_pass http://trojan_hu;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinVlHU {
            proxy_pass http://vless_hu;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinSSHU {
            proxy_pass http://shadowsocks_hu;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinVMHU {
            proxy_pass http://vmess_hu;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }

        location ^~ /CxlvinTRXH {
            proxy_pass http://[::1]:10010;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinVlXH {
            proxy_pass http://[::1]:10009;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinSSXH {
            proxy_pass http://[::1]:10012;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
        location ^~ /CxlvinVMXH {
            proxy_pass http://[::1]:10011;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_socket_keepalive on;
        }
    }
}
EOF

# =========================
#   ENTRYPOINT.SH
# =========================
cat > entrypoint.sh <<'EOF'
#!/bin/sh
set -e

export PORT="${PORT:-8080}"
echo "Cxlvin Server Host starting on PORT: $PORT"

NGINX_CONF="/usr/local/openresty/nginx/conf/nginx.conf"

sed -i.bak "s/listen 8080 default_server/listen $PORT default_server/g" "$NGINX_CONF"
sed -i.bak "s/listen \[::\]:8080 default_server/listen [::]:$PORT default_server/g" "$NGINX_CONF"
rm -f "${NGINX_CONF}.bak"

echo "Starting Xray..."
/usr/local/bin/xray run -c /etc/xray.json &
XRAY_PID=$!

for i in 1 2 3 4 5 6 7 8 9 10 15 20 25 30; do
  if kill -0 $XRAY_PID 2>/dev/null; then
    echo "Xray fully ready after ${i}s"
    break
  fi
  sleep 1
done

echo "Starting OpenResty..."
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF
chmod +x entrypoint.sh

# =========================
#   DOCKERFILE
# =========================
cat > Dockerfile <<'EOF'
FROM alpine:3.20 AS xray-bin
RUN apk add --no-cache curl unzip ca-certificates bash
WORKDIR /app
RUN curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip \
    && unzip xray.zip && chmod +x xray && mv xray /usr/local/bin/xray && rm -f xray.zip

FROM openresty/openresty:alpine-fat
RUN apk add --no-cache ca-certificates bash curl tzdata wget
RUN mkdir -p /usr/local/share/xray \
    && wget -qO /usr/local/share/xray/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat \
    && wget -qO /usr/local/share/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
COPY --from=xray-bin /usr/local/bin/xray /usr/local/bin/xray
COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/xray /entrypoint.sh
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s CMD wget -qO- http://[::1]:8080/health || exit 1
CMD /usr/local/bin/xray run -c /etc/xray.json & sleep 5 && exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}          BUILDING IMAGE 👾${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

BUILD_START=$(date +%s)
gcloud builds submit --tag gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME . --quiet
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

echo ""
echo -e "${GREEN}BUILD COMPLETED IN ${BUILD_TIME} SECONDS${NC}"

DEPLOY_START=$(date +%s)
if [ "$BILLING_MODE" = "instance" ]; then 
    BILLING_FLAGS="--no-cpu-throttling"
    BILLING_DISPLAY="Instance-Based"
else 
    BILLING_FLAGS="--cpu-throttling"
    BILLING_DISPLAY="Request-Based"
fi

gcloud run deploy $CLOUD_RUN_SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME \
  --platform managed --region $REGION --allow-unauthenticated --port 8080 \
  --memory $MEMORY --cpu $CPU --concurrency $CONCURRENCY --timeout $TIMEOUT \
  --min-instances $MIN_INST --max-instances $MAX_INST \
  --execution-environment gen2 --cpu-boost $BILLING_FLAGS --quiet

DEPLOY_END=$(date +%s)
DEPLOY_TIME=$((DEPLOY_END - DEPLOY_START))

CLOUD_RUN_URL=$(gcloud run services describe $CLOUD_RUN_SERVICE_NAME --region=$REGION --format='value(status.url)')

# =========================
#   TIMESTAMP
# =========================
echo "${DEPLOY_TIMESTAMP}|${REGION_DISPLAY}|${CLOUD_RUN_URL}" >> "$HISTORY_FILE"

# =========================
# FINAL DISPLAY
# =========================
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}DEPLOYMENT REPORT${NC}"
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}BUILD TIME:${NC} $BUILD_TIME seconds"
echo -e "${GREEN}DEPLOY TIME:${NC} $DEPLOY_TIME seconds"
echo -e "${GREEN}CLOUD RUN URL:${NC} $CLOUD_RUN_URL"
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}CONFIG DETAILS${NC}"
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}REGION:${NC}         $REGION_DISPLAY"
echo -e "${GREEN}MEMORY:${NC}         $MEMORY"
echo -e "${GREEN}vCPU:${NC}           $CPU"
echo -e "${GREEN}BILLING MODE:${NC}   $BILLING_DISPLAY"
echo -e "${GREEN}AUTO SCALING:${NC}"
echo -e "${GREEN}  MIN INSTANCES:${NC}  $MIN_INST"
echo -e "${GREEN}  MAX INSTANCES:${NC}  $MAX_INST"
echo -e "${GREEN}REVISION SCALING:${NC}"
echo -e "${GREEN}  MIN INSTANCES:${NC}  $MIN_INST"
echo -e "${GREEN}  MAX INSTANCES:${NC}  $MAX_INST"
echo -e "${GREEN}CONCURRENCY:${NC}    1000"
echo -e "${GREEN}TIMEOUT:${NC}        3600 seconds"
echo -e "${GREEN}EXECUTION ENV:${NC}  Gen2"
echo -e "${GREEN}CPU BOOST:${NC}      Enabled"
echo ""

while true; do
    echo -e "${WHITE}1) DEPLOY AGAIN${NC}"
    echo -e "${WHITE}2) EXIT${NC}"
    echo ""
    read -p "SELECT OPTION [1-2]: " FINAL_CHOICE
    case "$FINAL_CHOICE" in
        1) clear; echo -e "${GREEN}RESTARTING...${NC}"; sleep 1; clear; break ;;
        2) echo -e "${YELLOW}EXIT IN 10 SECONDS...${NC}"; for i in {10..1}; do echo -ne "${CYAN}CLOSING IN $i SECONDS...\r${NC}"; sleep 1; done; echo ""; exit 0 ;;
        *) echo -e "${RED}⚠ PLEASE PUT RIGHT VALUE 1 OR 2${NC}"; echo "" ;;
    esac
done

done
