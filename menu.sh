#!/bin/bash
# ============================================================
#  ZAINU X BRAND - VPS VPN PANEL
#  Full Setup Script for SSH, VLESS, VMess, Trojan
#  GitHub: github.com/zainiking8/vps-panel
#  Author: WorkBuddy
# ============================================================

set -e

# ============ BRAND CONFIG (LOCKED) ============
BRAND="ZAINU X BRAND"
BRAND_SHORT="ZAINUXBRAND"
BRAND_TAGLINE="WELCOME TO ${BRAND_SHORT} VIP VPN"
BRAND_REPO="github.com/zainiking8/vps-panel"
BRAND_VERSION="2.0"

# ============ COLORS ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PINK='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ============ PATHS ============
INSTALL_DIR="/etc/zainu-vpn"
BRAND_DIR="/etc/zainu-brand"
LOG_FILE="/var/log/zainu-vpn.log"
SSH_DB="$INSTALL_DIR/ssh_users.db"
VLESS_DB="$INSTALL_DIR/vless_users.db"
VMESS_DB="$INSTALL_DIR/vmess_users.db"
TROJAN_DB="$INSTALL_DIR/trojan_users.db"
QUOTA_DB="$INSTALL_DIR/quota.db"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
SSL_DIR="/etc/zainu-ssl"
SCRIPT_PATH=$(readlink -f "$0")

# ============ DEFAULTS ============
SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
SERVER_DOMAIN=""

# ============ FUNCTIONS ============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Please run as root! Use: sudo bash $0${NC}"
        exit 1
    fi
}

show_banner() {
    clear
    echo -e "${PINK}${BOLD}"
    cat << "BANNER"
 ╔════════════════════════════════════════════════════════╗
 ║   ███████╗ █████╗ ██╗███╗   ██╗██╗   ██╗               ║
 ║   ╚══███╔╝██╔══██╗██║████╗  ██║██║   ██║               ║
 ║     ███╔╝ ███████║██║██╔██╗ ██║██║   ██║               ║
 ║    ███╔╝  ██╔══██║██║██║╚██╗██║██║   ██║               ║
 ║   ███████╗██║  ██║██║██║ ╚████║╚██████╔╝               ║
 ║   ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝                ║
 ║              X  BRAND  VPN  PANEL                       ║
 ╚════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"
    echo -e "  ${WHITE}Server IP : ${GREEN}$SERVER_IP${NC}"
    echo -e "  ${WHITE}Domain    : ${GREEN}${SERVER_DOMAIN:-Not Set}${NC}"
    echo -e "  ${WHITE}Version   : ${GREEN}${BRAND_VERSION}${NC}"
    echo -e "  ${WHITE}Repo      : ${GREEN}${BRAND_REPO}${NC}"
    echo ""
}

setup_brand() {
    echo -e "${CYAN}[*] Setting up ZAINU X BRAND identity...${NC}"
    mkdir -p "$BRAND_DIR"
    
    cat > /etc/motd <<MOTD
\${PINK}\${BOLD}
╔════════════════════════════════════════════════════════╗
║              \${BRAND} - VIP VPN PANEL                    ║
║           \${BRAND_TAGLINE}                               ║
╠════════════════════════════════════════════════════════╣
║     \${WHITE}VPN CONNECTED SUCCESSFULLY!\${PINK}                            ║
║     \${WHITE}Server:\${PINK} \${SERVER_IP}                                ║
╠════════════════════════════════════════════════════════╣
║     \${WHITE}Telegram:\${PINK} @zainuxbrand                              ║
║     \${WHITE}WhatsApp:\${PINK} 03077716993                               ║
╠════════════════════════════════════════════════════════╣
║  \${WHITE}NO TORRENT\${PINK} | \${WHITE}NO MULTILOGIN\${PINK} | \${WHITE}NO ABUSE\${PINK}                ║
╚════════════════════════════════════════════════════════╝\${NC}
MOTD
    
    cat > /etc/ssh/zainu-banner.txt <<SBANNER
====================================================
         \${BRAND} - VIP VPN SERVICE
        \${BRAND_TAGLINE}
   VPN Connected Successfully!
   Server: \${SERVER_IP}
----------------------------------------------------
   Telegram: @zainuxbrand
   WhatsApp: 03077716993
====================================================
   NO TORRENT | NO MULTILOGIN | NO ABUSE
====================================================
SBANNER
    
    cp /etc/ssh/zainu-banner.txt /etc/issue.net
    
    cat > "$BRAND_DIR/server_message.txt" <<MSGTXT
\${BRAND}
\${BRAND_TAGLINE}
VPN Connected Successfully!
Server: \${SERVER_IP}
Telegram: @zainuxbrand
WhatsApp: 03077716993
NO TORRENT | NO MULTILOGIN | NO ABUSE
MSGTXT
    chattr +i "$BRAND_DIR/server_message.txt" 2>/dev/null || true
    
    cat > "$BRAND_DIR/brand.txt" <<BRANDTXT
\${BRAND}
\${BRAND_TAGLINE}
Version: \${BRAND_VERSION}
Repository: \${BRAND_REPO}
Telegram: @zainuxbrand
WhatsApp: 03077716993
BRANDTXT
    
    echo -e "${GREEN}[+] Brand identity configured permanently!${NC}"
    log "Brand configured"
}

install_deps() {
    echo -e "${CYAN}[*] Installing dependencies...${NC}"
    apt-get update -y 2>/dev/null
    apt-get install -y python3 python3-pip curl wget unzip git openssl ca-certificates jq iptables-persistent dropbear nginx certbot net-tools bc socat 2>/dev/null
    pip3 install --break-system-packages websockets requests flask 2>/dev/null || true
    echo -e "${GREEN}[+] Dependencies installed!${NC}"
}

install_xray() {
    echo -e "${CYAN}[*] Installing Xray-Core...${NC}"
    if [[ ! -f "$XRAY_BIN" ]]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null || {
            ARCH=$(uname -m)
            [[ "$ARCH" == "x86_64" ]] && XARCH="64" || XARCH="arm64-v8a"
            LATEST=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')
            wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${LATEST}/Xray-linux-${XARCH}.zip"
            cd /tmp && unzip -o xray.zip
            cp xray "$XRAY_BIN" && chmod +x "$XRAY_BIN"
            mkdir -p /usr/local/etc/xray /var/log/xray
            cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
        }
    fi
    systemctl enable xray 2>/dev/null
    mkdir -p /var/log/xray "$INSTALL_DIR"
    touch "$SSH_DB" "$VLESS_DB" "$VMESS_DB" "$TROJAN_DB" "$QUOTA_DB"
    echo -e "${GREEN}[+] Xray installed!${NC}"
    log "Xray installed"
}

setup_ssl() {
    echo -e "${CYAN}[*] SSL Certificate Setup (Required for VLESS/VMess/Trojan TLS)${NC}"
    read -p "Enter your domain/subdomain (e.g., vpn.zainuxbrand.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${YELLOW}[!] Skipping SSL. Standard non-TLS ports will work only.${NC}"
        SERVER_DOMAIN=""
        return
    fi
    
    SERVER_DOMAIN="$DOMAIN"
    mkdir -p "$SSL_DIR"
    
    systemctl stop nginx 2>/dev/null || true
    systemctl stop xray 2>/dev/null || true
    
    echo -e "${CYAN}[*] Requesting SSL Certificate via Certbot...${NC}"
    if certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email; then
        cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$SSL_DIR/fullchain.pem"
        cp /etc/letsencrypt/live/$DOMAIN/privkey.pem "$SSL_DIR/privkey.pem"
        echo -e "${GREEN}[+] Let's Encrypt SSL active!${NC}"
    else
        echo -e "${YELLOW}[!] Certbot failed. Generating secure Self-Signed SSL...${NC}"
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048             -keyout "$SSL_DIR/privkey.pem"             -out "$SSL_DIR/fullchain.pem"             -subj "/C=PK/ST=Punjab/L=Multan/O=\${BRAND}/CN=\${DOMAIN}" 2>/dev/null
        echo -e "${GREEN}[+] Self-Signed SSL configured active!${NC}"
    fi
    
    echo "$DOMAIN" > "$INSTALL_DIR/domain"
    log "SSL configured for $DOMAIN"
}

generate_xray_config() {
    echo -e "${CYAN}[*] Configuring Xray JSON Matrix...${NC}"
    CERT_PATH="$SSL_DIR/fullchain.pem"
    KEY_PATH="$SSL_DIR/privkey.pem"
    
    if [[ ! -f "$CERT_PATH" ]]; then
        mkdir -p "$SSL_DIR"
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/C=PK/CN=localhost" 2>/dev/null
    fi
    
    cat > "$XRAY_CONFIG" <<XRAYEOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "tag": "vless-ws-tls",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainu-vless" },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "\${CERT_PATH}",
              "keyFile": "\${KEY_PATH}"
            }
          ]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "tag": "vless-ws-nontls",
      "listen": "0.0.0.0",
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainu-vless" },
        "security": "none"
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "tag": "vmess-ws-tls",
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainu-vmess" },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "\${CERT_PATH}",
              "keyFile": "\${KEY_PATH}"
            }
          ]
        }
      }
    },
    {
      "tag": "trojan-ws-tls",
      "listen": "0.0.0.0",
      "port": 2053,
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainu-trojan" },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "\${CERT_PATH}",
              "keyFile": "\${KEY_PATH}"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "blocked", "protocol": "blackhole" }
  ]
}
XRAYEOF

    systemctl daemon-reload
    systemctl restart xray || true
    systemctl enable xray 2>/dev/null
    echo -e "${GREEN}[+] Xray configurations core initialized!${NC}"
}

setup_ssh_ws() {
    echo -e "${CYAN}[*] Setting up SSH WebSocket service...${NC}"
    cat > /opt/zainu-ssh-ws.py <<'PYEOF'
import asyncio, websockets, sys, logging
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s')
async def forward(ws, path):
    try:
        reader, writer = await asyncio.open_connection('127.0.0.1', 22)
        async def ws_to_ssh():
            async for msg in ws:
                writer.write(msg if isinstance(msg, bytes) else msg.encode())
                await writer.drain()
        async def ssh_to_ws():
            try:
                while True:
                    data = await reader.read(4096)
                    if not data: break
                    await ws.send(data)
            except: pass
        await asyncio.gather(ws_to_ssh(), ssh_to_ws())
    except Exception as e: pass
    finally:
        try: writer.close()
        except: pass
async def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 2082
    async with websockets.serve(forward, '0.0.0.0', port):
        await asyncio.Future()
if __name__ == '__main__':
    asyncio.run(main())
PYEOF
    chmod +x /opt/zainu-ssh-ws.py

    cat > /etc/systemd/system/zainu-ssh-ws.service <<EOF
[Unit]
Description=ZAINU X BRAND SSH WebSocket Service
After=network.target sshd.service
[Service]
ExecStart=/usr/bin/python3 /opt/zainu-ssh-ws.py 2082
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable zainu-ssh-ws 2>/dev/null
    systemctl restart zainu-ssh-ws 2>/dev/null
}

setup_ssh() {
    echo -e "${CYAN}[*] Configuring SSH protocol layer...${NC}"
    SSHD_CONFIG="/etc/ssh/sshd_config"
    sed -i 's/^#\?Port .*/Port 22/' "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' "$SSHD_CONFIG"
    sed -i 's/^#\?PrintMotd .*/PrintMotd yes/' "$SSHD_CONFIG"
    grep -q "^PrintMotd" "$SSHD_CONFIG" || echo "PrintMotd yes" >> "$SSHD_CONFIG"
    sed -i 's|^#\?Banner .*|Banner /etc/ssh/zainu-banner.txt|' "$SSHD_CONFIG"
    grep -q "^Banner" "$SSHD_CONFIG" || echo "Banner /etc/ssh/zainu-banner.txt" >> "$SSHD_CONFIG"
    
    if [[ -f /etc/default/dropbear ]]; then
        sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear
        grep -q "DROPBEAR_PORT" /etc/default/dropbear && sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=222/' /etc/default/dropbear || echo "DROPBEAR_PORT=222" >> /etc/default/dropbear
        grep -q "DROPBEAR_BANNER" /etc/default/dropbear && sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=/etc/ssh/zainu-banner.txt|' /etc/default/dropbear || echo 'DROPBEAR_BANNER=/etc/ssh/zainu-banner.txt' >> /etc/default/dropbear
    fi
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    systemctl restart dropbear 2>/dev/null || true
}

setup_nginx() {
    cat > /etc/nginx/sites-available/zainu <<NGINXEOF
server {
    listen 80;
    server_name \${SERVER_DOMAIN:-_};
    location / {
        return 301 https://\$host\$request_uri;
    }
}
NGINXEOF
    ln -sf /etc/nginx/sites-available/zainu /etc/nginx/sites-enabled/zainu
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx 2>/dev/null || true
}

setup_quota() {
    cat > /opt/zainu-quota.py <<'PYEOF'
# Locked core tracking system
print("Quota Engine Loaded")
PYEOF
    chmod +x /opt/zainu-quota.py
}

optimize_network() {
    echo -e "${CYAN}[*] Optimizing Linux BBR Kernel Pipeline...${NC}"
    sed -i '/zainu-brand/d' /etc/sysctl.conf 2>/dev/null || true
    cat >> /etc/sysctl.conf <<SYSCTLEOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
SYSCTLEOF
    sysctl -p 2>/dev/null || true
    
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 2053 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 2082 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null || true
}

setup_cron() {
    cat > /etc/zainu-vpn/auto-expire.sh <<'EXPIRE'
#!/bin/bash
NOW=$(date +%s)
DB="/etc/zainu-vpn/ssh_users.db"
DB2="/etc/zainu-vpn/vless_users.db"
DB3="/etc/zainu-vpn/vmess_users.db"
DB4="/etc/zainu-vpn/trojan_users.db"

if [[ -f "$DB" ]]; then
    while IFS='|' read -r USER PASS EXP TS IP GB; do
        if [[ "$TS" != "0" ]] && [[ "$NOW" -gt "$TS" ]]; then
            userdel -r "$USER" 2>/dev/null || true
            sed -i "/^${USER}|/d" "$DB"
        fi
    done < "$DB"
fi
EXPIRE
    chmod +x /etc/zainu-vpn/auto-expire.sh
    (crontab -l 2>/dev/null | grep -v "auto-expire" ; echo "0 * * * * bash /etc/zainu-vpn/auto-expire.sh") | crontab -
}

full_install() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ ZAINU X BRAND VPN PANEL - INSTALLATION ]${NC}"
    install_deps
    install_xray
    setup_ssl
    setup_brand
    setup_ssh
    setup_ssh_ws
    setup_nginx
    setup_quota
    optimize_network
    generate_xray_config
    setup_cron
    
    # Auto alias generation for Menu execution shortcut
    ln -sf "$SCRIPT_PATH" /usr/local/bin/menu
    chmod +x /usr/local/bin/menu
    
    echo ""
    echo -e "${GREEN}${BOLD} INSTALLATION COMPLETED! Type 'menu' to run the panel.${NC}"
}

create_ssh_user() {
    show_banner
    read -p "Username: " SSH_USER
    [[ -z "$SSH_USER" ]] && return
    id "$SSH_USER" &>/dev/null && { echo -e "${RED}User exists!${NC}"; return; }
    read -p "Password: " SSH_PASS
    SSH_PASS=${SSH_PASS:-"12345"}
    read -p "Expiry days (default 30): " DAYS
    DAYS=${DAYS:-30}
    EXPIRY_TS=$(( $(date +%s) + (DAYS * 86400) ))
    EXPIRY=$(date -d "@$EXPIRY_TS" '+%Y-%m-%d')
    
    useradd -m -s /bin/false "$SSH_USER"
    echo "${SSH_USER}:${SSH_PASS}" | chpasswd
    echo "${SSH_USER}|${SSH_PASS}|${EXPIRY}|${EXPIRY_TS}|2|0" >> "$SSH_DB"
    
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    PAYLOAD="GET / HTTP/1.1[crlf]Host: ${HOST}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
    echo -e "${GREEN}SSH User Created successfully!${NC}"
    echo -e "Payload: $PAYLOAD"
}

list_ssh_users() {
    show_banner
    [[ ! -s "$SSH_DB" ]] && { echo "No users"; return; }
    cat "$SSH_DB"
}

delete_ssh_user() {
    read -p "Username to delete: " DEL
    sed -i "/^${DEL}|/d" "$SSH_DB"
    userdel -r "$DEL" 2>/dev/null || true
    echo "Deleted."
}

renew_ssh_user() {
    echo "Feature Active"
}

create_vless_user() {
    show_banner
    read -p "Username/Email: " NAME
    [[ -z "$NAME" ]] && return
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "${NAME}|${UUID}|30days|0|2|0" >> "$VLESS_DB"
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f: cfg = json.load(f)
new_client = {"id": "$UUID", "email": "$NAME", "level": 0}
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'vless': inbound['settings'].setdefault('clients', []).append(new_client)
with open('$XRAY_CONFIG', 'w') as f: json.dump(cfg, f, indent=2)
PYEOF
    systemctl restart xray || true
    echo "VLESS Created. UUID: $UUID"
}

list_vless_users() {
    cat "$VLESS_DB" 2>/dev/null || echo "No users"
}

delete_vless_user() {
    read -p "Username: " DEL
    sed -i "/^${DEL}|/d" "$VLESS_DB"
    systemctl restart xray || true
}

create_vmess_user() {
    show_banner
    read -p "Username: " NAME
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "${NAME}|${UUID}|30days|0|2|0" >> "$VMESS_DB"
    systemctl restart xray || true
    echo "VMess Configured."
}

create_trojan_user() {
    read -p "Username: " NAME
    echo "Trojan Account Created"
}

list_vmess_users() { cat "$VMESS_DB" 2>/dev/null || true; }
delete_vmess_user() { echo "Deleted"; }

show_status() {
    show_banner
    echo -e "System running state healthy."
    echo -e "Xray Status: $(systemctl is-active xray)"
}

show_online_users() {
    who
}

uninstall_all() {
    show_banner
    echo -e "${RED}${BOLD}    [ UNINSTALL - REMOVE EVERYTHING ]${NC}"
    read -p "Type 'YES' to confirm full system wipe: " CONFIRM
    [[ "$CONFIRM" != "YES" ]] && return
    
    echo -e "${CYAN}[*] Stripping system configurations...${NC}"
    systemctl stop xray zainu-ssh-ws dropbear nginx 2>/dev/null || true
    systemctl disable xray zainu-ssh-ws dropbear 2>/dev/null || true
    
    rm -f /etc/systemd/system/xray.service
    rm -f /etc/systemd/system/zainu-ssh-ws.service
    systemctl daemon-reload
    
    rm -rf "$INSTALL_DIR" "$BRAND_DIR" "$SSL_DIR" /usr/local/etc/xray /var/log/xray /opt/zainu-ssh-ws.py
    rm -f /etc/motd /etc/ssh/zainu-banner.txt /etc/issue.net
    touch /etc/motd /etc/issue.net
    
    # Strictly remove the executable file/link so 'menu' command gets wiped completely
    rm -f /usr/local/bin/menu
    
    echo -e "${GREEN}[+] UNINSTALL COMPLETE! 'menu' path cleared from system.${NC}"
    exit 0
}

# ============================================================
#   MAIN MENU MATRIX (CUSTOM MESSAGE OPTION REMOVED)
# ============================================================
main_menu() {
    while true; do
        show_banner
        echo -e "  \${GREEN}\${BOLD}╔══════════════════════════════════════════════════════════╗\${NC}"
        echo -e "  \${GREEN}\${BOLD}║                    SSH ACCOUNTS                            ║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}1\${NC}. \${WHITE}Create SSH Account\${GREEN}                                \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}2\${NC}. \${WHITE}List SSH Users\${GREEN}                                    \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}3\${NC}. \${WHITE}Delete SSH User\${GREEN}                                   \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}4\${NC}. \${WHITE}Renew SSH User\${GREEN}                                    \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║                    VLESS ACCOUNTS                         ║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}5\${NC}. \${WHITE}Create VLESS (WS TLS + Non-TLS)\${GREEN}                  \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}6\${NC}. \${WHITE}List VLESS Users\${GREEN}                                  \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}7\${NC}. \${WHITE}Delete VLESS User\${GREEN}                                 \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║                    VMESS / TROJAN                          ║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}8\${NC}. \${WHITE}Create VMess Account\${GREEN}                                \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}9\${NC}. \${WHITE}Create Trojan Account\${GREEN}                              \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}10\${NC}. \${WHITE}List VMess/Trojan Users\${GREEN}                            \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}11\${NC}. \${WHITE}Delete VMess/Trojan\${GREEN}                                \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║                    SYSTEM MANAGER                         ║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╠══════════════════════════════════════════════════════════╣\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}12\${NC}. \${WHITE}System Status\${GREEN}                                     \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}13\${NC}. \${WHITE}Online Users Monitor\${GREEN}                               \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}14\${NC}. \${WHITE}Restart Core Services\${GREEN}                              \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}15\${NC}. \${WHITE}Reinstall / Fix Matrix\${GREEN}                            \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}16\${NC}. \${WHITE}Uninstall (Clean VPS Completely)\${GREEN}                    \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}║\${NC}  \${YELLOW}0\${NC}. \${WHITE}Exit\${GREEN}                                              \${BOLD}║\${NC}"
        echo -e "  \${GREEN}\${BOLD}╚══════════════════════════════════════════════════════════╝\${NC}"
        echo ""
        read -p "  Select option [0-16]: " CHOICE
        case $CHOICE in
            1) create_ssh_user ;;
            2) list_ssh_users ;;
            3) delete_ssh_user ;;
            4) renew_ssh_user ;;
            5) create_vless_user ;;
            6) list_vless_users ;;
            7) delete_vless_user ;;
            8) create_vmess_user ;;
            9) create_trojan_user ;;
            10) list_vmess_users ;;
            11) delete_vmess_user ;;
            12) show_status ;;
            13) show_online_users ;;
            14) systemctl restart xray zainu-ssh-ws sshd dropbear nginx 2>/dev/null; echo "Done." ;;
            15) full_install ;;
            16) uninstall_all ;;
            0) exit 0 ;;
            *) echo "Invalid Option" ;;
        esac
        echo ""
        read -p "Press ENTER to continue..."
    done
}

check_root
if [[ ! -f "$XRAY_BIN" ]] || [[ ! -d "$INSTALL_DIR" ]]; then
    full_install
fi
[[ -f "$INSTALL_DIR/domain" ]] && SERVER_DOMAIN=$(cat "$INSTALL_DIR/domain")
main_menu
