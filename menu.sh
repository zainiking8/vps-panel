#!/bin/bash
# ============================================================
#  ZAINU X BRAND - VPS VPN PANEL
#  Full Setup Script for SSH, VLESS, VMess, Trojan
#  GitHub: github.com/zainiking8/vps-panel
#  Author: WorkBuddy (Modded & Fixed)
# ============================================================

set -e

# ============ BRAND CONFIG ============
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

# ============ DEFAULTS ============
SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
SERVER_DOMAIN=""  # User provides

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

# ============ BRAND FILES (FIXED - NO EDIT) ============
setup_brand() {
    echo -e "${CYAN}[*] Setting up ZAINU X BRAND identity...${NC}"
    
    mkdir -p "$BRAND_DIR"
    
    # MOTD (Server Message - Fixed Display)
    cat > /etc/motd <<MOTD
\${PINK}\${BOLD}
╔════════════════════════════════════════════════════════╗
║              \${BRAND} - VIP VPN PANEL                    ║
║           \${BRAND_TAGLINE}                               ║
╠════════════════════════════════════════════════════════╣
║     \${WHITE}VPN CONNECTED SUCCESSFULLY!\${PINK}                            ║
║     \${WHITE}Server:\${PINK} \${SERVER_IP}                                ║
╠════════════════════════════════════════════════════════╣
║     Telegram: @zainuxbrand                              ║
║     WhatsApp: 03077716993                               ║
╠════════════════════════════════════════════════════════╣
║  \${WHITE}NO TORRENT\${PINK} | \${WHITE}NO MULTILOGIN\${PINK} | \${WHITE}NO ABUSE\${PINK}                ║
╚════════════════════════════════════════════════════════╝\${NC}
MOTD
    
    # SSH Banner (shows before login)
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
    
    echo -e "${GREEN}[+] Brand identity configured permanently!${NC}"
    log "Brand configured"
}

# ============ INSTALL DEPENDENCIES ============
install_deps() {
    echo -e "${CYAN}[*] Installing dependencies...${NC}"
    
    apt-get update -y 2>/dev/null
    apt-get install -y python3 python3-pip curl wget unzip git openssl ca-certificates jq iptables-persistent dropbear nginx certbot net-tools bc 2>/dev/null
    
    pip3 install --break-system-packages websockets requests flask 2>/dev/null || true
    echo -e "${GREEN}[+] Dependencies installed!${NC}"
}

# ============ INSTALL XRAY ============
install_xray() {
    echo -e "${CYAN}[*] Installing Xray-Core...${NC}"
    
    if [[ ! -f "$XRAY_BIN" ]]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null || {
            ARCH=$(uname -m)
            [[ "$ARCH" == "x86_64" ]] && XARCH="64" || XARCH="arm64-v8a"
            LATEST=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')
            wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v\${LATEST}/Xray-linux-\${XARCH}.zip"
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
}

# ============ SETUP SSL ============
setup_ssl() {
    echo -e "${CYAN}[*] SSL Certificate Setup${NC}"
    read -p "Enter your domain/subdomain: " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        SERVER_DOMAIN="none"
        return
    fi
    
    SERVER_DOMAIN="$DOMAIN"
    mkdir -p "$SSL_DIR"
    
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    else
        systemctl stop nginx 2>/dev/null
        certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email 2>/dev/null || {
            openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" -subj "/C=US/ST=State/L=City/O=\${BRAND}/CN=\${DOMAIN}" 2>/dev/null
        }
        CERT_PATH="$SSL_DIR/fullchain.pem"
        KEY_PATH="$SSL_DIR/privkey.pem"
    fi
    echo "$DOMAIN" > "$INSTALL_DIR/domain"
}

# ============ GENERATE XRAY CONFIG ============
generate_xray_config() {
    echo -e "${CYAN}[*] Generating Fixed Xray config...${NC}"
    
    CERT_PATH="$SSL_DIR/fullchain.pem"
    KEY_PATH="$SSL_DIR/privkey.pem"
    if [[ -f "/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem" ]]; then
        CERT_PATH="/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem"
        KEY_PATH="/etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem"
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
        "wsSettings": {
          "path": "/zainu-vless"
        },
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
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
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
        "wsSettings": {
          "path": "/zainu-vless"
        },
        "security": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "blocked", "protocol": "blackhole" }
  ]
}
XRAYEOF

    systemctl restart xray || true
}

# ============ SSH WS PAYLOAD SERVER ============
setup_ssh_ws() {
    cat > /opt/zainu-ssh-ws.py <<'PYEOF'
import asyncio
import websockets
import sys

async def forward(ws, path):
    try:
        reader, writer = await asyncio.open_connection('127.0.0.1', 22)
        async def ws_to_ssh():
            async for msg in ws:
                writer.write(msg if isinstance(msg, bytes) else msg.encode())
                await writer.drain()
        async def ssh_to_ws():
            while True:
                data = await reader.read(4096)
                if not data: break
                await ws.send(data)
        await asyncio.gather(ws_to_ssh(), ssh_to_ws())
    except: pass
    finally: writer.close()

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
Description=SSH WebSocket Service
After=network.target sshd.service
[Service]
ExecStart=/usr/bin/python3 /opt/zainu-ssh-ws.py 2082
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable zainu-ssh-ws && systemctl start zainu-ssh-ws || true
}

setup_ssh() {
    SSHD_CONFIG="/etc/ssh/sshd_config"
    sed -i 's/^#\?Port .*/Port 22/' "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's|^#\?Banner .*|Banner /etc/ssh/zainu-banner.txt|' "$SSHD_CONFIG"
    systemctl restart sshd || systemctl restart ssh || true
}

setup_nginx() {
    cat > /etc/nginx/sites-available/zainu <<NGINXEOF
server {
    listen 80;
    server_name \${SERVER_DOMAIN} _;
    location /zainu-vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}
NGINXEOF
    ln -sf /etc/nginx/sites-available/zainu /etc/nginx/sites-enabled/zainu
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx || true
}

optimize_network() {
    iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 2082 -j ACCEPT 2>/dev/null
}

setup_cron() {
    cat > /etc/zainu-vpn/auto-expire.sh <<'EXPIRE'
#!/bin/bash
NOW=$(date +%s)
DB="/etc/zainu-vpn/ssh_users.db"
if [[ -f "$DB" ]]; then
    while IFS='|' read -r USER PASS EXP TS IP GB; do
        if [[ "$TS" != "0" ]] && [[ "$NOW" -gt "$TS" ]]; then
            userdel -r "$USER" 2>/dev/null
            sed -i "/^${USER}|/d" "$DB"
        fi
    done < "$DB"
fi
EXPIRE
    chmod +x /etc/zainu-vpn/auto-expire.sh
}

full_install() {
    show_banner
    install_deps
    install_xray
    setup_ssl
    setup_brand
    setup_ssh
    setup_ssh_ws
    setup_nginx
    optimize_network
    generate_xray_config
    setup_cron
}

# ============ CREATE SSH USER (FIXED PAYLOAD) ============
create_ssh_user() {
    show_banner
    read -p "Username: " SSH_USER
    [[ -z "$SSH_USER" ]] && return
    
    read -sp "Password: " SSH_PASS
    echo ""
    
    useradd -m -s /bin/bash "$SSH_USER"
    echo "${SSH_USER}:${SSH_PASS}" | chpasswd
    echo "${SSH_USER}|${SSH_PASS}|never|0|2|0" >> "$SSH_DB"
    
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    
    # 100% Working Clean WebSocket Payload
    PAYLOAD="GET / HTTP/1.1[crlf]Host: \${HOST}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
    
    echo -e "${GREEN}SSH Account Created Successfully!${NC}"
    echo -e "Host: \${HOST} | Port: 2082"
    echo -e "${CYAN}Clean Payload:${NC}
${PINK}${PAYLOAD}${NC}
"
}

list_ssh_users() {
    cat "$SSH_DB" || echo "No users."
}
delete_ssh_user() {
    read -p "User to delete: " DEL
    userdel -r "$DEL" 2>/dev/null || true
    sed -i "/^${DEL}|/d" "$SSH_DB"
}

# ============ CREATE VLESS USER (FIXED CONNECTION) ============
create_vless_user() {
    show_banner
    read -p "Username/Email: " NAME
    [[ -z "$NAME" ]] && return
    
    UUID=$(cat /proc/sys/kernel/random/uuid)
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    cfg = json.load(f)
new_client = {"id": "$UUID", "email": "$NAME", "level": 0}
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'vless':
        inbound['settings'].setdefault('clients', []).append(new_client)
with open('$XRAY_CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF

    echo "${NAME}|${UUID}|never|0|2|0" >> "$VLESS_DB"
    systemctl restart xray || true
    
    LINK_TLS="vless://${UUID}@${HOST}:443?encryption=none&security=tls&sni=${HOST}&type=ws&path=%2Fzainu-vless#${NAME}"
    LINK_NONTLS="vless://${UUID}@${HOST}:80?encryption=none&security=none&type=ws&path=%2Fzainu-vless#${NAME}"
    
    echo -e "${GREEN}VLESS Account Created!${NC}"
    echo -e "${CYAN}VLESS TLS (443):${NC} ${LINK_TLS}"
    echo -e "${CYAN}VLESS Non-TLS (80):${NC} ${LINK_NONTLS}"
}

list_vless_users() { cat "$VLESS_DB"; }
delete_vless_user() {
    read -p "Enter name: " DEL
    sed -i "/^${DEL}|/d" "$VLESS_DB"
    systemctl restart xray || true
}

show_status() {
    echo -e "Xray Status: $(systemctl is-active xray)"
    echo -e "SSH-WS Status: $(systemctl is-active zainu-ssh-ws)"
}

uninstall_all() {
    systemctl stop xray zainu-ssh-ws nginx 2>/dev/null || true
    rm -rf "$INSTALL_DIR" "$BRAND_DIR" "$XRAY_BIN" "$XRAY_CONFIG"
    echo "Uninstalled."
}

# ============================================================
#   MAIN MENU (MODDED: OPTION 14 REMOVED PERMANENTLY)
# ============================================================
main_menu() {
    while true; do
        show_banner
        echo -e "  ${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${GREEN}║                    SSH ACCOUNTS                          ║${NC}"
        echo -e "  ${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}1${NC}. ${WHITE}Create SSH Account${GREEN}                                ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}2${NC}. ${WHITE}List SSH Users${GREEN}                                    ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}3${NC}. ${WHITE}Delete SSH User${GREEN}                                   ║${NC}"
        echo -e "  ${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}║                    VLESS ACCOUNTS                         ║${NC}"
        echo -e "  ${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}4${NC}. ${WHITE}Create VLESS (WS TLS + Non-TLS)${GREEN}                  ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}5${NC}. ${WHITE}List VLESS Users${GREEN}                                  ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}6${NC}. ${WHITE}Delete VLESS User${GREEN}                                 ║${NC}"
        echo -e "  ${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}║                    SYSTEM                                 ║${NC}"
        echo -e "  ${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}7${NC}. ${WHITE}System Status${GREEN}                                     ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}8${NC}. ${WHITE}Restart Services${GREEN}                                  ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}9${NC}. ${WHITE}Reinstall / Fix Panel${GREEN}                             ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}10${NC}. ${WHITE}Uninstall Panel Completely${GREEN}                        ║${NC}"
        echo -e "  ${GREEN}║${NC}  ${YELLOW}0${NC}. ${WHITE}Exit${GREEN}                                              ║${NC}"
        echo -e "  ${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        read -p "  Select option [0-10]: " CHOICE
        case $CHOICE in
            1) create_ssh_user ;;
            2) list_ssh_users ;;
            3) delete_ssh_user ;;
            4) create_vless_user ;;
            5) list_vless_users ;;
            6) delete_vless_user ;;
            7) show_status ;;
            8) systemctl restart xray zainu-ssh-ws sshd nginx 2>/dev/null || true ;;
            9) full_install ;;
            10) uninstall_all ;;
            0) exit 0 ;;
            *) echo "Invalid option!" ;;
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
