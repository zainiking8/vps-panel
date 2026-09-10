#!/bin/bash
#====================================================
#  ZAINI X BRAND PREMIUM VPN SCRIPT
#  Master Installer
#  Features:
#   - SSH OpenSSH + Dropbear WebSocket
#   - SSL Stunnel (443)
#   - VLESS WS/TLS + VLESS WS non-TLS (Xray-core)
#   - Nginx with Let's Encrypt / Self-signed SSL
#   - Custom Banner "ZAINUXBRAND VIP VPN"
#   - User management with limits
#   - Uninstall option
#====================================================

export DEBIAN_FRONTEND=noninteractive
export TERM=xterm

#------------- REPO (auto-download menu + uninstall) -------------
REPO_RAW="https://raw.githubusercontent.com/zainiking8/vps-panel/main"

#------------- COLORS -------------
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

#------------- BRAND -------------
BRAND="ZAINI X BRAND"
BANNER_TXT="WELCOME TO ZAINUXBRAND VIP VPN"

#------------- PATHS -------------
BASE_DIR="/etc/zainix-brand"
LOG_FILE="$BASE_DIR/install.log"
DB_USERS="$BASE_DIR/users.db"
DOMAIN_FILE="$BASE_DIR/domain.txt"
CERT_DIR="/etc/nginx/ssl"
NGINX_CONF="/etc/nginx/conf.d/zainix.conf"
XRAY_CONF="/usr/local/etc/xray/config.json"
STUNNEL_CONF="/etc/stunnel/stunnel.conf"
DROPBEAR_CONF="/etc/default/dropbear"

mkdir -p "$BASE_DIR"
touch "$LOG_FILE"

#------------- HEADER -------------
header() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${R}    ${BRAND} PREMIUM VPN SCRIPT${N}"
    echo -e "${Y}=====================================================${N}"
    echo -e "${C}   SSH  •  SSL  •  WS Dropbear  •  VLESS WS/TLS${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
}

#------------- ROOT CHECK -------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${R}ERROR: This script must be run as root.${N}"
    echo -e "Use: ${G}bash install.sh${N}"
    exit 1
fi

#------------- OS CHECK -------------
. /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo -e "${R}Unsupported OS. Use Ubuntu 20.04/22.04 or Debian 11/12.${N}"
    exit 1
fi

#------------- LOGGING -------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

#------------- UPDATE SYSTEM -------------
update_system() {
    echo -e "${Y}[1/9] Updating system packages...${N}"
    apt update -y >> "$LOG_FILE" 2>&1
    apt upgrade -y >> "$LOG_FILE" 2>&1
    apt install -y curl wget git socat cron unzip zip nginx certbot python3-certbot-nginx \
        stunnel4 dropbear openssl uuid-runtime net-tools htop nano jq \
        libssl-dev netcat-openbsd iptables-persistent build-essential >> "$LOG_FILE" 2>&1
}

#------------- DOMAIN SETUP -------------
setup_domain() {
    header
    echo -e "${Y}[2/9] Domain Setup${N}"
    echo ""
    PUBLIC_IP=$(curl -s4 ifconfig.me)
    echo -e "${C}Detected public IP: ${G}$PUBLIC_IP${N}"
    echo ""
    echo -e "${W}1) Use a real domain (recommended for TLS)${N}"
    echo -e "${W}2) Use IP only (no TLS, non-TLS mode)${N}"
    read -p "Select option [1/2]: " DOMAIN_OPT
    case $DOMAIN_OPT in
        1)
            read -p "Enter your domain (e.g. vpn.example.com): " DOMAIN
            echo "$DOMAIN" > "$DOMAIN_FILE"
            DNSIP=$(dig +short "$DOMAIN" @resolver1.opendns.com 2>/dev/null || echo "$PUBLIC_IP")
            if [[ "$DNSIP" != "$PUBLIC_IP" ]]; then
                echo -e "${Y}WARNING: Domain DNS ($DNSIP) does not match server IP ($PUBLIC_IP).${N}"
                echo -e "${Y}Certificate generation may fail.${N}"
                sleep 3
            fi
            ;;
        *)
            DOMAIN="$PUBLIC_IP"
            echo "$DOMAIN" > "$DOMAIN_FILE"
            ;;
    esac
    echo -e "${G}Domain set to: $DOMAIN${N}"
}

#------------- SSL CERTIFICATE -------------
setup_ssl() {
    header
    echo -e "${Y}[3/9] Setting up SSL certificate...${N}"
    mkdir -p "$CERT_DIR"
    PUBLIC_IP=$(curl -s4 ifconfig.me)
    DOMAIN=$(cat "$DOMAIN_FILE")

    if [[ "$DOMAIN" == "$PUBLIC_IP" ]] || [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${Y}Generating self-signed certificate (IP mode)...${N}"
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=PK/ST=PB/L=Islamabad/O=${BRAND}/CN=$DOMAIN" \
            -keyout "$CERT_DIR/private.key" \
            -out "$CERT_DIR/cert.crt" >> "$LOG_FILE" 2>&1
    else
        echo -e "${Y}Requesting Let's Encrypt certificate for $DOMAIN...${N}"
        systemctl stop nginx 2>/dev/null
        certbot certonly --standalone --agree-tos --register-unsafely-without-email \
            -d "$DOMAIN" >> "$LOG_FILE" 2>&1
        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/cert.crt"
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/private.key"
            echo -e "${G}Let's Encrypt certificate installed.${N}"
        else
            echo -e "${Y}Falling back to self-signed certificate...${N}"
            openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
                -subj "/C=PK/ST=PB/L=Islamabad/O=${BRAND}/CN=$DOMAIN" \
                -keyout "$CERT_DIR/private.key" \
                -out "$CERT_DIR/cert.crt" >> "$LOG_FILE" 2>&1
        fi
        systemctl start nginx 2>/dev/null
    fi

    # Convert cert to PEM format for stunnel/xray
    if [[ -f "$CERT_DIR/cert.crt" && -f "$CERT_DIR/private.key" ]]; then
        cat "$CERT_DIR/cert.crt" "$CERT_DIR/private.key" > "$CERT_DIR/full.pem"
        chmod 600 "$CERT_DIR/private.key"
        chmod 644 "$CERT_DIR/cert.crt"
    fi
}

#------------- NGINX -------------
setup_nginx() {
    header
    echo -e "${Y}[4/9] Configuring Nginx...${N}"
    DOMAIN=$(cat "$DOMAIN_FILE")
    PUBLIC_IP=$(curl -s4 ifconfig.me)

    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN $PUBLIC_IP;

    # Nginx port 80 par hi VLESS non-TLS ko bypass karega
    location /vless-ws {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        return 200 'ZAINI X BRAND VPN OK';
        add_header Content-Type text/plain;
    }
}

server {
    listen 8443 ssl;
    listen [::]:8443 ssl;
    server_name $DOMAIN $PUBLIC_IP;

    ssl_certificate     $CERT_DIR/cert.crt;
    ssl_certificate_key $CERT_DIR/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    # VLESS WS TLS ke liye
    location /vless-ws {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # SSH WebSocket bridge proxy endpoint
    location /ws-ssh {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:8882;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location / {
        return 200 'ZAINI X BRAND - Premium VPN Active';
        add_header Content-Type text/plain;
    }
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    systemctl enable nginx >> "$LOG_FILE" 2>&1
    systemctl restart nginx >> "$LOG_FILE" 2>&1
}

#------------- SSH / DROPBEAR -------------
setup_ssh() {
    header
    echo -e "${Y}[5/9] Setting up SSH (OpenSSH + Dropbear WebSocket)...${N}"

    # OpenSSH
    apt install -y openssh-server >> "$LOG_FILE" 2>&1
    sed -i 's/#\?Port 22/Port 22/' /etc/ssh/sshd_config
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl enable ssh >> "$LOG_FILE" 2>&1
    systemctl restart ssh >> "$LOG_FILE" 2>&1

    # Dropbear on custom ports
    cat > "$DROPBEAR_CONF" <<EOF
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 110 -w"
EOF
    systemctl enable dropbear >> "$LOG_FILE" 2>&1
    systemctl restart dropbear >> "$LOG_FILE" 2>&1

    # wstunnel — proper SSH-over-WebSocket bridge
    install_wstunnel
}

#------------- WSTUNNEL (SSH WS Bridge) -------------
install_wstunnel() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  WARCH="amd64" ;;
        aarch64) WARCH="arm64" ;;
        *)       WARCH="amd64" ;;
    esac

    if [[ ! -f /usr/local/bin/wstunnel ]]; then
        echo -e "${Y}    Installing wstunnel (SSH WebSocket bridge)...${N}"
        cd /tmp
        wget -q "https://github.com/erebe/wstunnel/releases/download/v9.1.4/wstunnel_9.1.4_linux_${WARCH}.tar.gz" \
            -O wstunnel.tar.gz 2>>"$LOG_FILE"
        tar -xzf wstunnel.tar.gz 2>>"$LOG_FILE"
        mv wstunnel /usr/local/bin/wstunnel 2>/dev/null
        chmod +x /usr/local/bin/wstunnel
        rm -f wstunnel.tar.gz
    fi

    # systemd unit: WS listener on 8881 -> forward to local SSH 22
        cat > /etc/systemd/system/wstunnel-ssh.service <<'EOF'
[Unit]
Description=wstunnel SSH-over-WebSocket bridge (ZAINI X BRAND)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/wstunnel server --listen ws://127.0.0.1:8881 --listen ws://127.0.0.1:8882 --restrictTo=127.0.0.1:22
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable wstunnel-ssh >> "$LOG_FILE" 2>&1
    systemctl restart wstunnel-ssh >> "$LOG_FILE" 2>&1
}

#------------- STUNNEL (SSL) -------------
setup_stunnel() {
    header
    echo -e "${Y}[6/9] Setting up Stunnel (SSL on 443)...${N}"

    cat > "$STUNNEL_CONF" <<EOF
cert = $CERT_DIR/full.pem
pid = /var/run/stunnel.pid
client = no
socket = a:SO_REUSEADDR=1
TIMEOUTclose = 0

[ssh-ssl]
accept = 443
connect = 127.0.0.1:8881
EOF

    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
    systemctl enable stunnel4 >> "$LOG_FILE" 2>&1
    systemctl restart stunnel4 >> "$LOG_FILE" 2>&1
}

#------------- XRAY (VLESS) -------------
setup_xray() {
    header
    echo -e "${Y}[7/9] Installing Xray-core for VLESS...${N}"

    bash -c "$(curl -L https://github.com/Xray-install/raw/main/install-release.sh)" @ install >> "$LOG_FILE" 2>&1

    UUID=$(uuidgen)
    DOMAIN=$(cat "$DOMAIN_FILE")

    cat > "$XRAY_CONF" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 0,
            "email": "default@vless"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless-ws"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

    echo "$UUID" > "$BASE_DIR/uuid.txt"
    systemctl enable xray >> "$LOG_FILE" 2>&1
    systemctl restart xray >> "$LOG_FILE" 2>&1
}

#------------- BANNER / MOTD -------------
setup_banner() {
    header
    echo -e "${Y}[8/9] Installing custom banner...${N}"

    cat > /etc/issue.net <<'EOF'
=====================================================
      WELCOME TO ZAINUXBRAND VIP VPN
   - NO TORRENT / NO MULTILOGIN -
=====================================================
EOF

    cat > /etc/motd <<'EOF'
=====================================================
      WELCOME TO ZAINUXBRAND VIP VPN
   - NO TORRENT / NO MULTILOGIN -
=====================================================
EOF

    cat > /etc/banner <<'EOF'
=====================================================
      WELCOME TO ZAINUXBRAND VIP VPN
   - NO TORRENT / NO MULTILOGIN -
=====================================================
EOF

    # Dropbear banner
    cat > /etc/dropbear/banner <<'EOF'
=====================================================
      WELCOME TO ZAINUXBRAND VIP VPN
   - NO TORRENT / NO MULTILOGIN -
=====================================================
EOF

    sed -i 's|#\?Banner.*|Banner /etc/banner|' /etc/ssh/sshd_config
    sed -i 's|#\?PrintMotd.*|PrintMotd yes|' /etc/ssh/sshd_config
    sed -i 's|#\?PrintMotd.*|PrintMotd yes|' /etc/default/dropbear 2>/dev/null
    echo "DROPBEAR_BANNER=\"/etc/dropbear/banner\"" >> /etc/default/dropbear

    systemctl restart ssh >> "$LOG_FILE" 2>&1
    systemctl restart dropbear >> "$LOG_FILE" 2>&1
}

#------------- FIREWALL / PORTS -------------
setup_firewall() {
    header
    echo -e "${Y}[9/9] Configuring firewall and keeping 80/443 open...${N}"

    apt install -y ufw >> "$LOG_FILE" 2>&1
    ufw --force reset >> "$LOG_FILE" 2>&1
    ufw default allow incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Open all required ports
    for PORT in 22 80 443 109 110 444 8881 8443 10000; do
        ufw allow "$PORT"/tcp >> "$LOG_FILE" 2>&1
        ufw allow "$PORT"/udp >> "$LOG_FILE" 2>&1
    done

    ufw --force enable >> "$LOG_FILE" 2>&1

    # Disable conflicting services
    systemctl disable apache2 >> "$LOG_FILE" 2>&1
    systemctl stop apache2 >> "$LOG_FILE" 2>&1
}

#------------- MAIN INSTALL FLOW -------------
do_install() {
    header
    echo -e "${G}Starting full installation of ZAINI X BRAND PREMIUM VPN...${N}"
    echo ""
    sleep 2
    update_system
    setup_domain
    setup_ssl
    setup_nginx
    setup_ssh
    setup_stunnel
    setup_xray
    setup_banner
    setup_firewall

    # Auto-fetch menu and uninstall from the same GitHub repo
    echo -e "${Y}Fetching menu.sh and uninstall.sh from GitHub...${N}"
    curl -fsSL "$REPO_RAW/menu.sh"     -o /usr/local/bin/menu            || cp "$(dirname "$0")/menu.sh" /usr/local/bin/menu 2>/dev/null
    curl -fsSL "$REPO_RAW/uninstall.sh" -o /usr/local/bin/zainix-uninstall || cp "$(dirname "$0")/uninstall.sh" /usr/local/bin/zainix-uninstall 2>/dev/null
    chmod +x /usr/local/bin/menu /usr/local/bin/zainix-uninstall 2>/dev/null

    header
    echo -e "${G}=====================================================${N}"
    echo -e "${G}    INSTALLATION COMPLETE!${N}"
    echo -e "${G}=====================================================${N}"
    echo ""
    echo -e "${W}Type ${C}menu${W} to open the VPN control panel.${N}"
    echo ""
    echo -e "${W}Server Message:${N}"
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}      ${BANNER_TXT}${N}"
    echo -e "${R}   - NO TORRENT / NO MULTILOGIN -${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    echo -e "${W}Uninstall command: ${R}zainix-uninstall${N}"
    echo ""
}

do_install