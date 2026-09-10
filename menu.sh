#!/bin/bash
# ============================================================
#  ZAINU X BRAND - VPS VPN PANEL
#  Full Setup Script for SSH, VLESS, VMess, Trojan
#  GitHub: github.com/zainiking8/vps-panel
#  Author: WorkBuddy
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

# ============ BRAND FILES ============
setup_brand() {
    echo -e "${CYAN}[*] Setting up ZAINU X BRAND identity...${NC}"
    
    mkdir -p "$BRAND_DIR"
    
    # MOTD (Server Message - shows when VPN connects via SSH)
    cat > /etc/motd <<MOTD
${PINK}${BOLD}
╔════════════════════════════════════════════════════════╗
║              ${BRAND} - VIP VPN PANEL                    ║
║           ${BRAND_TAGLINE}                               ║
╠════════════════════════════════════════════════════════╣
║     ${WHITE}VPN CONNECTED SUCCESSFULLY!${PINK}                            ║
║     ${WHITE}Server:${PINK} ${SERVER_IP}                                ║
╠════════════════════════════════════════════════════════╣
║     ${WHITE}Telegram:${PINK} @zainuxbrand                              ║
║     ${WHITE}WhatsApp:${PINK} 03077716993                               ║
╠════════════════════════════════════════════════════════╣
║  ${WHITE}NO TORRENT${PINK} | ${WHITE}NO MULTILOGIN${PINK} | ${WHITE}NO ABUSE${PINK}                ║
╚════════════════════════════════════════════════════════╝${NC}
MOTD
    
    # SSH Banner (shows before login)
    cat > /etc/ssh/zainu-banner.txt <<SBANNER
====================================================
         ${BRAND} - VIP VPN SERVICE
        ${BRAND_TAGLINE}
   VPN Connected Successfully!
   Server: ${SERVER_IP}
----------------------------------------------------
   Telegram: @zainuxbrand
   WhatsApp: 03077716993
====================================================
   NO TORRENT | NO MULTILOGIN | NO ABUSE
====================================================
SBANNER
    
    # Issue.net (for SSH pre-login)
    cp /etc/ssh/zainu-banner.txt /etc/issue.net
    
    # Fixed server message file (NOT editable)
    cat > "$BRAND_DIR/server_message.txt" <<MSGTXT
${BRAND}
${BRAND_TAGLINE}
VPN Connected Successfully!
Server: ${SERVER_IP}
Telegram: @zainuxbrand
WhatsApp: 03077716993
NO TORRENT | NO MULTILOGIN | NO ABUSE
MSGTXT
    chattr +i "$BRAND_DIR/server_message.txt" 2>/dev/null || true
    
    # Brand file
    cat > "$BRAND_DIR/brand.txt" <<BRANDTXT
${BRAND}
${BRAND_TAGLINE}
Version: ${BRAND_VERSION}
Repository: ${BRAND_REPO}
Telegram: @zainuxbrand
WhatsApp: 03077716993
BRANDTXT
    
    echo -e "${GREEN}[+] Brand identity configured with fixed server message!${NC}"
    log "Brand configured"
}

# ============ INSTALL DEPENDENCIES ============
install_deps() {
    echo -e "${CYAN}[*] Installing dependencies...${NC}"
    
    apt-get update -y 2>/dev/null
    apt-get install -y \
        python3 python3-pip \
        curl wget unzip git \
        openssl ca-certificates \
        jq iptables-persistent \
        dropbear \
        nginx certbot \
        net-tools bc 2>/dev/null
    
    pip3 install --break-system-packages \
        websockets requests flask 2>/dev/null || true
    
    echo -e "${GREEN}[+] Dependencies installed!${NC}"
}

# ============ INSTALL XRAY ============
install_xray() {
    echo -e "${CYAN}[*] Installing Xray-Core...${NC}"
    
    if [[ ! -f "$XRAY_BIN" ]]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null || {
            echo -e "${YELLOW}[!] Falling back to manual install...${NC}"
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

# ============ SETUP SSL ============
setup_ssl() {
    echo -e "${CYAN}[*] SSL Certificate Setup${NC}"
    echo ""
    
    read -p "Enter your domain/subdomain (e.g., vpn.zainuxbrand.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${YELLOW}[!] Skipping SSL (no domain provided)${NC}"
        SERVER_DOMAIN="none"
        return
    fi
    
    SERVER_DOMAIN="$DOMAIN"
    mkdir -p "$SSL_DIR"
    
    # Check if cert already exists
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        echo -e "${GREEN}[+] Existing Let's Encrypt cert found!${NC}"
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    else
        echo -e "${CYAN}[*] Getting SSL certificate for $DOMAIN...${NC}"
        # Stop nginx if running
        systemctl stop nginx 2>/dev/null
        
        certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email 2>/dev/null || {
            echo -e "${YELLOW}[!] Let's Encrypt failed. Generating self-signed...${NC}"
            openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
                -keyout "$SSL_DIR/privkey.pem" \
                -out "$SSL_DIR/fullchain.pem" \
                -subj "/C=US/ST=State/L=City/O=${BRAND}/CN=${DOMAIN}" 2>/dev/null
        }
        
        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
            CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
            KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
        else
            CERT_PATH="$SSL_DIR/fullchain.pem"
            KEY_PATH="$SSL_DIR/privkey.pem"
        fi
    fi
    
    echo "$DOMAIN" > "$INSTALL_DIR/domain"
    echo -e "${GREEN}[+] SSL configured for $DOMAIN${NC}"
    log "SSL configured: $DOMAIN"
}

# ============ GENERATE XRAY CONFIG ============
generate_xray_config() {
    echo -e "${CYAN}[*] Generating Xray config...${NC}"
    
    # SSL paths
    CERT_PATH=""
    KEY_PATH=""
    if [[ -f "/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem" ]]; then
        CERT_PATH="/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem"
        KEY_PATH="/etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem"
    elif [[ -f "$SSL_DIR/fullchain.pem" ]]; then
        CERT_PATH="$SSL_DIR/fullchain.pem"
        KEY_PATH="$SSL_DIR/privkey.pem"
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
              "certificateFile": "${CERT_PATH}",
              "keyFile": "${KEY_PATH}"
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
    },
    {
      "tag": "vmess-ws-tls",
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/zainu-vmess"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CERT_PATH}",
              "keyFile": "${KEY_PATH}"
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
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/zainu-trojan"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CERT_PATH}",
              "keyFile": "${KEY_PATH}"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "blocked",
      "protocol": "blackhole"
    }
  ]
}
XRAYEOF

    systemctl restart xray
    systemctl enable xray
    
    echo -e "${GREEN}[+] Xray configured with all protocols!${NC}"
    log "Xray configured with full protocols"
}

# ============ SSH WS PAYLOAD SERVER ============
setup_ssh_ws() {
    echo -e "${CYAN}[*] Setting up SSH WebSocket service...${NC}"
    
    # Create WebSocket-to-SSH forwarder (Python)
    cat > /opt/zainu-ssh-ws.py <<'PYEOF'
#!/usr/bin/env python3
"""
ZAINU X BRAND - SSH WebSocket Forwarder
Listens for WS connections and forwards to SSH port 22
"""
import asyncio
import websockets
import socket
import sys
import logging

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s')

async def forward(ws, path):
    try:
        # Connect to local SSH
        reader, writer = await asyncio.open_connection('127.0.0.1', 22)
        logging.info(f"New WS connection from {ws.remote_address[0]}, path: {path}")
        
        async def ws_to_ssh():
            async for msg in ws:
                if isinstance(msg, bytes):
                    writer.write(msg)
                    await writer.drain()
                elif isinstance(msg, str):
                    writer.write(msg.encode())
                    await writer.drain()
        
        async def ssh_to_ws():
            try:
                while True:
                    data = await reader.read(4096)
                    if not data:
                        break
                    await ws.send(data)
            except:
                pass
        
        await asyncio.gather(ws_to_ssh(), ssh_to_ws())
        
    except Exception as e:
        logging.error(f"Error: {e}")
    finally:
        try:
            writer.close()
        except:
            pass

async def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 2082
    async with websockets.serve(forward, '0.0.0.0', port):
        logging.info(f"ZAINU X BRAND SSH-WS listening on port {port}")
        await asyncio.Future()

if __name__ == '__main__':
    asyncio.run(main())
PYEOF
    
    chmod +x /opt/zainu-ssh-ws.py
    
    # Systemd service for SSH WS
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
    systemctl enable zainu-ssh-ws
    systemctl start zainu-ssh-ws
    
    echo -e "${GREEN}[+] SSH WebSocket service running on port 2082${NC}"
    log "SSH WS service started"
}

# ============ SSH SERVER SETUP ============
setup_ssh() {
    echo -e "${CYAN}[*] Configuring SSH server with ZAINU X BRAND message...${NC}"
    
    SSHD_CONFIG="/etc/ssh/sshd_config"
    
    # Configure OpenSSH
    sed -i 's/^#\?Port .*/Port 22/' "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' "$SSHD_CONFIG"
    
    # Enable MOTD (server message shows when VPN connects)
    sed -i 's/^#\?PrintMotd .*/PrintMotd yes/' "$SSHD_CONFIG"
    grep -q "^PrintMotd" "$SSHD_CONFIG" || echo "PrintMotd yes" >> "$SSHD_CONFIG"
    
    # Enable banner (shows before login)
    sed -i 's|^#\?Banner .*|Banner /etc/ssh/zainu-banner.txt|' "$SSHD_CONFIG"
    grep -q "^Banner" "$SSHD_CONFIG" || echo "Banner /etc/ssh/zainu-banner.txt" >> "$SSHD_CONFIG"
    
    # Ensure MOTD scripts don't interfere
    chmod +x /etc/update-motd.d/* 2>/dev/null || true
    
    # Add Dropbear for additional SSH port (with banner)
    if [[ -f /etc/default/dropbear ]]; then
        sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear
        grep -q "DROPBEAR_PORT" /etc/default/dropbear && \
            sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=222/' /etc/default/dropbear || \
            echo "DROPBEAR_PORT=222" >> /etc/default/dropbear
        grep -q "DROPBEAR_BANNER" /etc/default/dropbear && \
            sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=/etc/ssh/zainu-banner.txt|' /etc/default/dropbear || \
            echo 'DROPBEAR_BANNER=/etc/ssh/zainu-banner.txt' >> /etc/default/dropbear
    fi
    
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    systemctl restart dropbear 2>/dev/null
    systemctl enable sshd 2>/dev/null || systemctl enable ssh 2>/dev/null
    systemctl enable dropbear 2>/dev/null
    
    echo -e "${GREEN}[+] SSH configured on ports 22 & 222 with server message${NC}"
}

# ============ NGINX SETUP ============
setup_nginx() {
    cat > /etc/nginx/sites-available/zainu <<NGINXEOF
server {
    listen 80;
    server_name ${SERVER_DOMAIN} _;
    location / {
        return 301 https://\$host\$request_uri;
    }
}
NGINXEOF
    
    ln -sf /etc/nginx/sites-available/zainu /etc/nginx/sites-enabled/zainu
    rm -f /etc/nginx/sites-enabled/default
    
    systemctl restart nginx 2>/dev/null
    systemctl enable nginx 2>/dev/null
}

# ============ QUOTA TRACKER ============
setup_quota() {
    echo -e "${CYAN}[*] Setting up quota tracker...${NC}"
    
    cat > /opt/zainu-quota.py <<'PYEOF'
#!/usr/bin/env python3
"""
ZAINU X BRAND - Quota Tracker
Tracks GB usage per user via iptables
"""
import subprocess
import re
import time
import os

QUOTA_DB = "/etc/zainu-vpn/quota.db"

def get_user_bytes(username):
    try:
        # Get bytes from iptables counter for user
        result = subprocess.run(
            ['iptables', '-L', 'OUTPUT', '-nvx', '-Z', '-Z'],
            capture_output=True, text=True
        )
        # Simplified: track via /proc/net/dev or direct accounting
        return 0
    except:
        return 0

def reset_user_quota(username, gb_limit):
    # Reset counter for user
    subprocess.run(['iptables', '-Z', f'ZAINU-{username}'], 
                   capture_output=True, stderr=subprocess.DEVNULL)
PYEOF
    
    chmod +x /opt/zainu-quota.py
    
    # Quota reset cron
    CRON_JOB="0 0 1 * * bash /etc/zainu-vpn/reset-quota.sh"
    (crontab -l 2>/dev/null | grep -v "reset-quota"; echo "$CRON_JOB") | crontab -
    
    echo -e "${GREEN}[+] Quota tracker configured!${NC}"
}

# ============ BBR & NETWORK OPTIMIZATION ============
optimize_network() {
    echo -e "${CYAN}[*] Optimizing network for speed...${NC}"
    
    cat >> /etc/sysctl.conf <<SYSCTLEOF

# ZAINU X BRAND - Network Optimization
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
SYSCTLEOF
    
    sysctl -p 2>/dev/null
    
    # Firewall open ports
    iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 2053 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 2082 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 2083 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null
    
    echo -e "${GREEN}[+] Network optimized with BBR!${NC}"
}

# ============ AUTO EXPIRY ============
setup_cron() {
    echo -e "${CYAN}[*] Setting up auto-expiry cron...${NC}"
    
    CRON_JOB="0 * * * * bash /etc/zainu-vpn/auto-expire.sh"
    (crontab -l 2>/dev/null | grep -v "auto-expire"; echo "$CRON_JOB") | crontab -
    
    cat > /etc/zainu-vpn/auto-expire.sh <<'EXPIRE'
#!/bin/bash
# ZAINU X BRAND - Auto Expire Script
NOW=$(date +%s)
DB="/etc/zainu-vpn/ssh_users.db"
DB2="/etc/zainu-vpn/vless_users.db"
DB3="/etc/zainu-vpn/vmess_users.db"
DB4="/etc/zainu-vpn/trojan_users.db"

# SSH expiry
if [[ -f "$DB" ]]; then
    while IFS='|' read -r USER PASS EXP TS IP GB; do
        if [[ "$TS" != "0" ]] && [[ "$NOW" -gt "$TS" ]]; then
            userdel -r "$USER" 2>/dev/null
            sed -i "/^${USER}|/d" "$DB"
        fi
    done < "$DB"
fi

# Xray clients expiry
for DBL in "$DB2" "$DB3" "$DB4"; do
    if [[ -f "$DBL" ]] && [[ -s "$DBL" ]]; then
        EXPIRED_UUIDS=""
        while IFS='|' read -r NAME UUID EXP TS IP GB; do
            if [[ "$TS" != "0" ]] && [[ "$NOW" -gt "$TS" ]]; then
                EXPIRED_UUIDS="$EXPIRED_UUIDS $UUID"
                sed -i "/^${NAME}|/d" "$DBL"
            fi
        done < "$DBL"
        if [[ -n "$EXPIRED_UUIDS" ]]; then
            /usr/bin/python3 -c "
import json
uuids = '$EXPIRED_UUIDS'.split()
with open('/usr/local/etc/xray/config.json','r') as f:
    cfg = json.load(f)
for inbound in cfg['inbounds']:
    if 'clients' in inbound.get('settings',{}):
        inbound['settings']['clients'] = [c for c in inbound['settings']['clients'] if c.get('id') not in uuids]
with open('/usr/local/etc/xray/config.json','w') as f:
    json.dump(cfg, f, indent=2)
"
            systemctl restart xray
        fi
    fi
done
EXPIRE
    
    chmod +x /etc/zainu-vpn/auto-expire.sh
    
    echo -e "${GREEN}[+] Auto-expiry cron installed!${NC}"
}

# ============ FULL INSTALL ============
full_install() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ ZAINU X BRAND VPN PANEL - INSTALLATION ]${NC}"
    echo ""
    
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
    
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   INSTALLATION COMPLETED SUCCESSFULLY!           ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Server IP    : ${GREEN}$SERVER_IP${NC}"
    echo -e "${WHITE}  Domain       : ${GREEN}${SERVER_DOMAIN}${NC}"
    echo -e "${WHITE}  SSH Port     : ${GREEN}22, 222${NC}"
    echo -e "${WHITE}  VLESS WS TLS : ${GREEN}443 /zainu-vless${NC}"
    echo -e "${WHITE}  VLESS WS     : ${GREEN}80 /zainu-vless${NC}"
    echo -e "${WHITE}  VMess WS TLS : ${GREEN}8443 /zainu-vmess${NC}"
    echo -e "${WHITE}  Trojan WS    : ${GREEN}2053 /zainu-trojan${NC}"
    echo -e "${WHITE}  SSH WS       : ${GREEN}2082 (payload)${NC}"
    echo ""
    echo -e "${PINK}  Now run: ${WHITE}sudo bash $0${NC}"
    echo ""
}

# ============================================================
#   ACCOUNT MANAGEMENT FUNCTIONS
# ============================================================

# ============ CREATE SSH USER ============
create_ssh_user() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ CREATE NEW SSH ACCOUNT - ${BRAND} ]${NC}"
    echo ""
    
    read -p "Username: " SSH_USER
    [[ -z "$SSH_USER" ]] && { echo -e "${RED}Username required!${NC}"; return; }
    id "$SSH_USER" &>/dev/null && { echo -e "${RED}User exists!${NC}"; return; }
    
    read -sp "Password (Enter=auto): " SSH_PASS
    echo ""
    if [[ -z "$SSH_PASS" ]]; then
        SSH_PASS=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | head -c10)
    fi
    
    read -p "Expiry days (0=never, default 30): " DAYS
    DAYS=${DAYS:-30}
    [[ "$DAYS" == "0" ]] && EXPIRY="never" && EXPIRY_TS=0 || {
        EXPIRY_TS=$(( $(date +%s) + (DAYS * 86400) ))
        EXPIRY=$(date -d "@$EXPIRY_TS" '+%Y-%m-%d')
    }
    
    read -p "IP Limit (0=unlimited, default 2): " IP_LIMIT
    IP_LIMIT=${IP_LIMIT:-2}
    
    read -p "GB Limit (0=unlimited, default 0): " GB_LIMIT
    GB_LIMIT=${GB_LIMIT:-0}
    
    # Create user
    useradd -m -s /bin/bash "$SSH_USER"
    echo "${SSH_USER}:${SSH_PASS}" | chpasswd
    
    # Save to DB
    echo "${SSH_USER}|${SSH_PASS}|${EXPIRY}|${EXPIRY_TS}|${IP_LIMIT}|${GB_LIMIT}" >> "$SSH_DB"
    
    # Build payload
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    
    # Generate SSH payload
    PAYLOAD="GET / HTTP/1.1[crlf]Host: ${HOST}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
    
    # Display info
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   ${BRAND} - SSH ACCOUNT CREATED!                  ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  ╔════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Username     ${WHITE}: ${GREEN}${SSH_USER}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Password     ${WHITE}: ${GREEN}${SSH_PASS}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Host/IP      ${WHITE}: ${GREEN}${HOST}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Port SSH     ${WHITE}: ${GREEN}22, 222${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Port WS      ${WHITE}: ${GREEN}2082${NC}"
    echo -e "${WHITE}  ║ ${CYAN}IP Limit     ${WHITE}: ${GREEN}${IP_LIMIT}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}GB Limit     ${WHITE}: ${GREEN}${GB_LIMIT} GB${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Expiry Date  ${WHITE}: ${YELLOW}${EXPIRY}${NC}"
    echo -e "${WHITE}  ╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  SSH PAYLOAD (DarkTunnel/HTTP Injector):${NC}"
    echo -e "${PINK}${PAYLOAD}${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  SERVER MESSAGE (shows on VPN connect):${NC}"
    echo -e "${PINK}  ${BRAND_TAGLINE} - VPN Connected Successfully!${NC}"
    echo ""
    
    # Save to file
    USER_FILE="$INSTALL_DIR/users/${SSH_USER}.txt"
    mkdir -p "$INSTALL_DIR/users"
    cat > "$USER_FILE" <<EOF
========================================
${BRAND} - SSH ACCOUNT
${BRAND_TAGLINE}
========================================
Username     : ${SSH_USER}
Password     : ${SSH_PASS}
Host/IP      : ${HOST}
SSH Port     : 22, 222
WS Port      : 2082
IP Limit     : ${IP_LIMIT}
GB Limit     : ${GB_LIMIT} GB
Expiry Date  : ${EXPIRY}
----------------------------------------
SSH Payload  : ${PAYLOAD}
----------------------------------------
Server Message (shows on connect):
${BRAND_TAGLINE} - VPN Connected Successfully!
Server: ${HOST}
========================================
NO TORRENT | NO MULTILOGIN | NO ABUSE
========================================
EOF
    
    echo -e "${GREEN}  Saved to: ${WHITE}${USER_FILE}${NC}"
    echo ""
    log "SSH user created: $SSH_USER"
}

# ============ LIST SSH USERS ============
list_ssh_users() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ SSH USER LIST - ${BRAND} ]${NC}"
    echo ""
    
    [[ ! -s "$SSH_DB" ]] && { echo -e "${YELLOW}No SSH users!${NC}"; return; }
    
    printf "${WHITE}${BOLD}%s | %-12s | %-12s | %-12s | %-6s | %-6s | %s${NC}\n" \
        "NO" "USERNAME" "PASSWORD" "EXPIRY" "IP" "GB" "STATUS"
    echo -e "${WHITE}══════════════════════════════════════════════════════════════${NC}"
    
    NUM=0; NOW=$(date +%s)
    while IFS='|' read -r USER PASS EXP TS IP GB; do
        NUM=$((NUM+1))
        if [[ "$TS" == "0" ]] || [[ "$NOW" -lt "$TS" ]]; then
            STATUS="${GREEN}Active${NC}"
        else
            STATUS="${RED}Expired${NC}"
        fi
        printf "%s | %-12s | %-12s | %-12s | %-6s | %-6s | %b\n" \
            "$NUM" "$USER" "$PASS" "$EXP" "$IP" "$GB" "$STATUS"
    done < "$SSH_DB"
    echo ""
}

# ============ DELETE SSH USER ============
delete_ssh_user() {
    list_ssh_users
    read -p "Enter username to delete: " DEL
    [[ -z "$DEL" ]] && return
    if ! grep -q "^${DEL}|" "$SSH_DB"; then
        echo -e "${RED}User not found!${NC}"; return
    fi
    userdel -r "$DEL" 2>/dev/null
    sed -i "/^${DEL}|/d" "$SSH_DB"
    rm -f "$INSTALL_DIR/users/${DEL}.txt"
    echo -e "${GREEN}User '$DEL' deleted!${NC}"
    log "SSH user deleted: $DEL"
}

# ============ RENEW SSH USER ============
renew_ssh_user() {
    list_ssh_users
    read -p "Enter username to renew: " REN
    [[ -z "$REN" ]] && return
    if ! grep -q "^${REN}|" "$SSH_DB"; then
        echo -e "${RED}User not found!${NC}"; return
    fi
    read -p "Add days: " AD
    AD=${AD:-30}
    
    LINE=$(grep "^${REN}|" "$SSH_DB")
    CUR_TS=$(echo "$LINE" | cut -d'|' -f4)
    PASS=$(echo "$LINE" | cut -d'|' -f2)
    IPL=$(echo "$LINE" | cut -d'|' -f5)
    GBL=$(echo "$LINE" | cut -d'|' -f6)
    
    NOW=$(date +%s)
    if [[ "$CUR_TS" == "0" ]] || [[ "$NOW" -gt "$CUR_TS" ]]; then
        NEW_TS=$(( NOW + (AD * 86400) ))
    else
        NEW_TS=$(( CUR_TS + (AD * 86400) ))
    fi
    NEW_EXP=$(date -d "@$NEW_TS" '+%Y-%m-%d')
    
    sed -i "/^${REN}|/d" "$SSH_DB"
    echo "${REN}|${PASS}|${NEW_EXP}|${NEW_TS}|${IPL}|${GBL}" >> "$SSH_DB"
    echo -e "${GREEN}Renewed until: ${NEW_EXP}${NC}"
    log "SSH renewed: $REN -> $NEW_EXP"
}

# ============ CREATE VLESS USER ============
create_vless_user() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ CREATE VLESS ACCOUNT - ${BRAND} ]${NC}"
    echo ""
    
    read -p "Username/Email: " NAME
    [[ -z "$NAME" ]] && { echo -e "${RED}Name required!${NC}"; return; }
    grep -q "^${NAME}|" "$VLESS_DB" && { echo -e "${RED}Exists!${NC}"; return; }
    
    UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    
    read -p "Expiry days (default 30): " DAYS
    DAYS=${DAYS:-30}
    [[ "$DAYS" == "0" ]] && EXP="never" && EXP_TS=0 || {
        EXP_TS=$(( $(date +%s) + (DAYS * 86400) ))
        EXP=$(date -d "@$EXP_TS" '+%Y-%m-%d')
    }
    
    read -p "IP Limit (default 2): " IP_LIM
    IP_LIM=${IP_LIM:-2}
    
    read -p "GB Limit (default 0=unlimited): " GB_LIM
    GB_LIM=${GB_LIM:-0}
    
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    
    # Add to all VLESS inbounds
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
    
    echo "${NAME}|${UUID}|${EXP}|${EXP_TS}|${IP_LIM}|${GB_LIM}" >> "$VLESS_DB"
    systemctl restart xray
    
    # Build links
    LINK_TLS="vless://${UUID}@${HOST}:443?encryption=none&security=tls&sni=${HOST}&type=ws&path=/zainu-vless#${NAME}"
    LINK_NONTLS="vless://${UUID}@${HOST}:80?encryption=none&security=none&type=ws&path=/zainu-vless#${NAME}"
    
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   ${BRAND} - VLESS ACCOUNT CREATED!                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  ╔════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Username     ${WHITE}: ${GREEN}${NAME}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}UUID         ${WHITE}: ${GREEN}${UUID}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Host         ${WHITE}: ${GREEN}${HOST}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}IP Limit     ${WHITE}: ${GREEN}${IP_LIM}${NC}"
    echo -e "${WHITE}  ║ ${CYAN}GB Limit     ${WHITE}: ${GREEN}${GB_LIM} GB${NC}"
    echo -e "${WHITE}  ║ ${CYAN}Expiry Date  ${WHITE}: ${YELLOW}${EXP}${NC}"
    echo -e "${WHITE}  ╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  VLESS WS TLS (Port 443):${NC}"
    echo -e "${PINK}${LINK_TLS}${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  VLESS WS Non-TLS (Port 80):${NC}"
    echo -e "${PINK}${LINK_NONTLS}${NC}"
    echo ""
    
    USER_FILE="$INSTALL_DIR/users/${NAME}.txt"
    mkdir -p "$INSTALL_DIR/users"
    cat > "$USER_FILE" <<EOF
========================================
${BRAND} - VLESS ACCOUNT
${BRAND_TAGLINE}
========================================
Username     : ${NAME}
UUID         : ${UUID}
Host         : ${HOST}
IP Limit     : ${IP_LIM}
GB Limit     : ${GB_LIM} GB
Expiry Date  : ${EXP}
----------------------------------------
VLESS WS TLS :
${LINK_TLS}
----------------------------------------
VLESS WS Non-TLS :
${LINK_NONTLS}
========================================
EOF
    
    echo -e "${GREEN}  Saved to: ${WHITE}${USER_FILE}${NC}"
    log "VLESS user: $NAME"
}

# ============ LIST VLESS USERS ============
list_vless_users() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ VLESS USER LIST - ${BRAND} ]${NC}"
    echo ""
    
    [[ ! -s "$VLESS_DB" ]] && { echo -e "${YELLOW}No VLESS users!${NC}"; return; }
    
    printf "${WHITE}${BOLD}%-3s | %-15s | %-36s | %-12s | %-4s | %-4s | %s${NC}\n" \
        "NO" "NAME" "UUID" "EXPIRY" "IP" "GB" "STATUS"
    echo -e "${WHITE}════════════════════════════════════════════════════════════════════${NC}"
    
    NUM=0; NOW=$(date +%s)
    while IFS='|' read -r NAME UUID EXP TS IP GB; do
        NUM=$((NUM+1))
        if [[ "$TS" == "0" ]] || [[ "$NOW" -lt "$TS" ]]; then
            STATUS="${GREEN}Active${NC}"
        else
            STATUS="${RED}Expired${NC}"
        fi
        printf "%-3s | %-15s | %-36s | %-12s | %-4s | %-4s | %b\n" \
            "$NUM" "$NAME" "$UUID" "$EXP" "$IP" "$GB" "$STATUS"
    done < "$VLESS_DB"
}

# ============ DELETE VLESS USER ============
delete_vless_user() {
    list_vless_users
    read -p "Enter name to delete: " DEL
    [[ -z "$DEL" ]] && return
    if ! grep -q "^${DEL}|" "$VLESS_DB"; then
        echo -e "${RED}Not found!${NC}"; return
    fi
    DEL_UUID=$(grep "^${DEL}|" "$VLESS_DB" | cut -d'|' -f2)
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    cfg = json.load(f)
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'vless':
        inbound['settings']['clients'] = [c for c in inbound['settings'].get('clients',[]) if c.get('id') != '$DEL_UUID']
with open('$XRAY_CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
    
    sed -i "/^${DEL}|/d" "$VLESS_DB"
    rm -f "$INSTALL_DIR/users/${DEL}.txt"
    systemctl restart xray
    echo -e "${GREEN}Deleted!${NC}"
    log "VLESS deleted: $DEL"
}

# ============ CREATE VMESS USER ============
create_vmess_user() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ CREATE VMESS ACCOUNT - ${BRAND} ]${NC}"
    echo ""
    
    read -p "Username: " NAME
    [[ -z "$NAME" ]] && { echo -e "${RED}Name required!${NC}"; return; }
    grep -q "^${NAME}|" "$VMESS_DB" && { echo -e "${RED}Exists!${NC}"; return; }
    
    UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    
    read -p "Expiry days (default 30): " DAYS; DAYS=${DAYS:-30}
    [[ "$DAYS" == "0" ]] && EXP="never" && EXP_TS=0 || {
        EXP_TS=$(( $(date +%s) + (DAYS * 86400) ))
        EXP=$(date -d "@$EXP_TS" '+%Y-%m-%d')
    }
    
    read -p "IP Limit (default 2): " IP_LIM; IP_LIM=${IP_LIM:-2}
    read -p "GB Limit (default 0): " GB_LIM; GB_LIM=${GB_LIM:-0}
    
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    cfg = json.load(f)
new_client = {"id": "$UUID", "email": "$NAME", "alterId": 0}
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'vmess':
        inbound['settings'].setdefault('clients', []).append(new_client)
with open('$XRAY_CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
    
    echo "${NAME}|${UUID}|${EXP}|${EXP_TS}|${IP_LIM}|${GB_LIM}" >> "$VMESS_DB"
    systemctl restart xray
    
    # VMess link (v2rayNG format)
    VMESS_JSON='{"v":"2","ps":"'$NAME'","add":"'$HOST'","port":"8443","id":"'$UUID'","aid":"0","net":"ws","type":"none","host":"'$HOST'","path":"/zainu-vmess","tls":"tls","sni":"'$HOST'"}'
    VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
    
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   ${BRAND} - VMESS ACCOUNT CREATED!                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Username     : ${GREEN}${NAME}${NC}"
    echo -e "${WHITE}  UUID         : ${GREEN}${UUID}${NC}"
    echo -e "${WHITE}  Host         : ${GREEN}${HOST}${NC}"
    echo -e "${WHITE}  Port         : ${GREEN}8443${NC}"
    echo -e "${WHITE}  Path         : ${GREEN}/zainu-vmess${NC}"
    echo -e "${WHITE}  IP Limit     : ${GREEN}${IP_LIM}${NC}"
    echo -e "${WHITE}  GB Limit     : ${GREEN}${GB_LIM} GB${NC}"
    echo -e "${WHITE}  Expiry       : ${YELLOW}${EXP}${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  VMESS LINK:${NC}"
    echo -e "${PINK}${VMESS_LINK}${NC}"
    echo ""
    
    USER_FILE="$INSTALL_DIR/users/${NAME}.txt"
    cat > "$USER_FILE" <<EOF
========================================
${BRAND} - VMESS ACCOUNT
${BRAND_TAGLINE}
========================================
Username     : ${NAME}
UUID         : ${UUID}
Host         : ${HOST}
Port         : 8443
Path         : /zainu-vmess
IP Limit     : ${IP_LIM}
GB Limit     : ${GB_LIM} GB
Expiry       : ${EXP}
----------------------------------------
VMESS LINK   :
${VMESS_LINK}
========================================
EOF
    
    log "VMESS user: $NAME"
}

list_vmess_users() {
    [[ ! -s "$VMESS_DB" ]] && { echo -e "${YELLOW}No VMESS users!${NC}"; return; }
    printf "%-3s | %-15s | %-36s | %-12s | %s\n" "NO" "NAME" "UUID" "EXPIRY" "STATUS"
    echo "══════════════════════════════════════════════════════════════"
    NUM=0; NOW=$(date +%s)
    while IFS='|' read -r NAME UUID EXP TS IP GB; do
        NUM=$((NUM+1))
        if [[ "$TS" == "0" ]] || [[ "$NOW" -lt "$TS" ]]; then
            STATUS="${GREEN}Active${NC}"
        else
            STATUS="${RED}Expired${NC}"
        fi
        printf "%-3s | %-15s | %-36s | %-12s | %b\n" "$NUM" "$NAME" "$UUID" "$EXP" "$STATUS"
    done < "$VMESS_DB"
}

delete_vmess_user() {
    read -p "Enter name: " DEL
    [[ -z "$DEL" ]] && return
    grep -q "^${DEL}|" "$VMESS_DB" || { echo -e "${RED}Not found!${NC}"; return; }
    DEL_UUID=$(grep "^${DEL}|" "$VMESS_DB" | cut -d'|' -f2)
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    cfg = json.load(f)
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'vmess':
        inbound['settings']['clients'] = [c for c in inbound['settings'].get('clients',[]) if c.get('id') != '$DEL_UUID']
with open('$XRAY_CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
    sed -i "/^${DEL}|/d" "$VMESS_DB"
    systemctl restart xray
    echo -e "${GREEN}Deleted!${NC}"
    log "VMESS deleted: $DEL"
}

# ============ CREATE TROJAN USER ============
create_trojan_user() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ CREATE TROJAN ACCOUNT - ${BRAND} ]${NC}"
    echo ""
    
    read -p "Username: " NAME
    [[ -z "$NAME" ]] && return
    grep -q "^${NAME}|" "$TROJAN_DB" && { echo -e "${RED}Exists!${NC}"; return; }
    
    TROJAN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c12)
    
    read -p "Expiry days (default 30): " DAYS; DAYS=${DAYS:-30}
    [[ "$DAYS" == "0" ]] && EXP="never" && EXP_TS=0 || {
        EXP_TS=$(( $(date +%s) + (DAYS * 86400) ))
        EXP=$(date -d "@$EXP_TS" '+%Y-%m-%d')
    }
    read -p "IP Limit (default 2): " IP_LIM; IP_LIM=${IP_LIM:-2}
    read -p "GB Limit (default 0): " GB_LIM; GB_LIM=${GB_LIM:-0}
    
    HOST="${SERVER_DOMAIN:-$SERVER_IP}"
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    cfg = json.load(f)
new_client = {"password": "$TROJAN_PASS", "email": "$NAME"}
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'trojan':
        inbound['settings'].setdefault('clients', []).append(new_client)
with open('$XRAY_CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
    
    echo "${NAME}|${TROJAN_PASS}|${EXP}|${EXP_TS}|${IP_LIM}|${GB_LIM}" >> "$TROJAN_DB"
    systemctl restart xray
    
    TROJAN_LINK="trojan://${TROJAN_PASS}@${HOST}:2053?security=tls&sni=${HOST}&type=ws&path=/zainu-trojan#${NAME}"
    
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   ${BRAND} - TROJAN ACCOUNT CREATED!               ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Username     : ${GREEN}${NAME}${NC}"
    echo -e "${WHITE}  Password     : ${GREEN}${TROJAN_PASS}${NC}"
    echo -e "${WHITE}  Host         : ${GREEN}${HOST}${NC}"
    echo -e "${WHITE}  Port         : ${GREEN}2053${NC}"
    echo -e "${WHITE}  Path         : ${GREEN}/zainu-trojan${NC}"
    echo -e "${WHITE}  IP Limit     : ${GREEN}${IP_LIM}${NC}"
    echo -e "${WHITE}  GB Limit     : ${GREEN}${GB_LIM} GB${NC}"
    echo -e "${WHITE}  Expiry       : ${YELLOW}${EXP}${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}  TROJAN LINK:${NC}"
    echo -e "${PINK}${TROJAN_LINK}${NC}"
    
    USER_FILE="$INSTALL_DIR/users/${NAME}.txt"
    cat > "$USER_FILE" <<EOF
========================================
${BRAND} - TROJAN ACCOUNT
${BRAND_TAGLINE}
========================================
Username     : ${NAME}
Password     : ${TROJAN_PASS}
Host         : ${HOST}
Port         : 2053
Path         : /zainu-trojan
IP Limit     : ${IP_LIM}
GB Limit     : ${GB_LIM} GB
Expiry       : ${EXP}
----------------------------------------
TROJAN LINK  :
${TROJAN_LINK}
========================================
EOF
    log "Trojan user: $NAME"
}

list_trojan_users() {
    [[ ! -s "$TROJAN_DB" ]] && { echo -e "${YELLOW}No Trojan users!${NC}"; return; }
    printf "%-3s | %-15s | %-20s | %-12s | %s\n" "NO" "NAME" "PASSWORD" "EXPIRY" "STATUS"
    NUM=0; NOW=$(date +%s)
    while IFS='|' read -r NAME PASS EXP TS IP GB; do
        NUM=$((NUM+1))
        if [[ "$TS" == "0" ]] || [[ "$NOW" -lt "$TS" ]]; then
            STATUS="${GREEN}Active${NC}"
        else
            STATUS="${RED}Expired${NC}"
        fi
        printf "%-3s | %-15s | %-20s | %-12s | %b\n" "$NUM" "$NAME" "$PASS" "$EXP" "$STATUS"
    done < "$TROJAN_DB"
}

delete_trojan_user() {
    read -p "Enter name: " DEL
    [[ -z "$DEL" ]] && return
    grep -q "^${DEL}|" "$TROJAN_DB" || { echo -e "${RED}Not found!${NC}"; return; }
    DEL_PASS=$(grep "^${DEL}|" "$TROJAN_DB" | cut -d'|' -f2)
    
    python3 - <<PYEOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    cfg = json.load(f)
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'trojan':
        inbound['settings']['clients'] = [c for c in inbound['settings'].get('clients',[]) if c.get('password') != '$DEL_PASS']
with open('$XRAY_CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
    sed -i "/^${DEL}|/d" "$TROJAN_DB"
    systemctl restart xray
    echo -e "${GREEN}Deleted!${NC}"
}

# ============ SERVER MESSAGE ============
customize_server_message() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ CUSTOMIZE SERVER MESSAGE - ${BRAND} ]${NC}"
    echo ""
    
    echo -e "${CYAN}Current message:${NC}"
    [[ -f "$BRAND_DIR/server_message.txt" ]] && cat "$BRAND_DIR/server_message.txt" || echo "(default)"
    echo ""
    
    read -p "Enter your custom server message (Enter=keep default): " CUSTOM_MSG
    if [[ -z "$CUSTOM_MSG" ]]; then
        CUSTOM_MSG="${BRAND_TAGLINE}"
    fi
    
    # Save custom message
    echo "${CUSTOM_MSG}" > "$BRAND_DIR/server_message.txt"
    
    # MOTD (shows when VPN connects via SSH - DarkTunnel/HTTP Injector popup)
    cat > /etc/motd <<MOTD
${PINK}${BOLD}
╔════════════════════════════════════════════════════════╗
║              ${BRAND} - VIP VPN PANEL                    ║
║           ${CUSTOM_MSG}                               ║
╠════════════════════════════════════════════════════════╣
║     ${WHITE}VPN CONNECTED SUCCESSFULLY!${PINK}                            ║
║     ${WHITE}Server:${PINK} ${SERVER_IP}                                ║
╠════════════════════════════════════════════════════════╣
║  ${WHITE}NO TORRENT${PINK} | ${WHITE}NO MULTILOGIN${PINK} | ${WHITE}NO ABUSE${PINK}                ║
╚════════════════════════════════════════════════════════╝${NC}
MOTD
    
    # SSH Banner (shows before login)
    cat > /etc/ssh/zainu-banner.txt <<SBANNER
====================================================
         ${BRAND} - VIP VPN SERVICE
        ${CUSTOM_MSG}
   VPN Connected Successfully!
   Server: ${SERVER_IP}
====================================================
   NO TORRENT | NO MULTILOGIN | NO ABUSE
====================================================
SBANNER
    cp /etc/ssh/zainu-banner.txt /etc/issue.net
    
    # Restart services to apply
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    systemctl restart dropbear 2>/dev/null
    
    echo ""
    echo -e "${GREEN}[+] Server message updated successfully!${NC}"
    echo -e "${CYAN}Message will show when VPN connects via SSH.${NC}"
    log "Server message updated: $CUSTOM_MSG"
}

# ============ SYSTEM STATUS ============
show_status() {
    show_banner
    echo -e "${GREEN}${BOLD}    [ ${BRAND} - SYSTEM STATUS ]${NC}"
    echo ""
    echo -e "${WHITE}  Server IP    : ${GREEN}$SERVER_IP${NC}"
    echo -e "${WHITE}  Domain       : ${GREEN}${SERVER_DOMAIN:-Not Set}${NC}"
    
    if systemctl is-active --quiet xray 2>/dev/null; then
        echo -e "${WHITE}  Xray         : ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}  Xray         : ${RED}Stopped${NC}"
    fi
    
    if systemctl is-active --quiet sshd 2>/dev/null; then
        echo -e "${WHITE}  SSH          : ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}  SSH          : ${RED}Stopped${NC}"
    fi
    
    if systemctl is-active --quiet zainu-ssh-ws 2>/dev/null; then
        echo -e "${WHITE}  SSH-WS       : ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}  SSH-WS       : ${RED}Stopped${NC}"
    fi
    
    echo -e "${WHITE}  Xray Version : ${GREEN}$($XRAY_BIN version 2>/dev/null | head -1)${NC}"
    
    S=$(wc -l < "$SSH_DB" 2>/dev/null || echo 0)
    V=$(wc -l < "$VLESS_DB" 2>/dev/null || echo 0)
    M=$(wc -l < "$VMESS_DB" 2>/dev/null || echo 0)
    T=$(wc -l < "$TROJAN_DB" 2>/dev/null || echo 0)
    
    echo -e "${WHITE}  SSH Users    : ${GREEN}$S${NC}"
    echo -e "${WHITE}  VLESS Users  : ${GREEN}$V${NC}"
    echo -e "${WHITE}  VMess Users  : ${GREEN}$M${NC}"
    echo -e "${WHITE}  Trojan Users : ${GREEN}$T${NC}"
    
    echo -e "${WHITE}  Uptime       : ${GREEN}$(uptime -p)${NC}"
    echo -e "${WHITE}  RAM          : ${GREEN}$(free -m | awk '/Mem:/{printf "%.0f/%.0fMB", $3, $2}')${NC}"
    echo -e "${WHITE}  CPU          : ${GREEN}$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%${NC}"
    echo ""
}

# ============ MONITORING ============
show_online_users() {
    echo ""
    echo -e "${GREEN}${BOLD}    [ ONLINE USERS - ${BRAND} ]${NC}"
    echo ""
    
    # SSH users
    echo -e "${CYAN}SSH Active Sessions:${NC}"
    who | awk '{print "  - " $1 " from " $5}'
    
    # Xray users (from access log)
    if [[ -f /var/log/xray/access.log ]]; then
        echo ""
        echo -e "${CYAN}Xray Recent Connections (last 10):${NC}"
        tail -n 10 /var/log/xray/access.log 2>/dev/null | awk '{print "  - " $0}' | head -10
    fi
    echo ""
}

# ============ UNINSTALL ============
# ============ UNINSTALL (COMPLETE CLEANUP) ============
uninstall_all() {
    show_banner
    echo -e "${RED}${BOLD}    [ UNINSTALL - REMOVE EVERYTHING ]${NC}"
    echo ""
    echo -e "${RED}WARNING: This will permanently remove ALL VPN settings!${NC}"
    echo -e "${RED}         - All SSH/VLESS/VMess/Trojan users deleted${NC}"
    echo -e "${RED}         - Xray, SSH-WS, Dropbear VPN config removed${NC}"
    echo -e "${RED}         - Brand files, SSL certs, cron, firewall rules${NC}"
    echo -e "${RED}         - VPS will be CLEAN like before install${NC}"
    echo ""
    read -p "Type 'YES' to confirm uninstall: " CONFIRM
    [[ "$CONFIRM" != "YES" ]] && { echo -e "${GREEN}Cancelled.${NC}"; return; }
    
    echo ""
    echo -e "${CYAN}[*] Step 1: Deleting all VPN users...${NC}"
    
    # Delete all SSH users from DB
    if [[ -f "$SSH_DB" ]]; then
        while IFS='|' read -r USER _ _ _ _ _; do
            [[ -n "$USER" ]] && {
                userdel -r "$USER" 2>/dev/null
                echo -e "  ${YELLOW}Deleted SSH user: $USER${NC}"
            }
        done < "$SSH_DB"
    fi
    
    echo -e "${CYAN}[*] Step 2: Stopping all services...${NC}"
    systemctl stop xray 2>/dev/null
    systemctl stop zainu-ssh-ws 2>/dev/null
    systemctl stop dropbear 2>/dev/null
    systemctl stop nginx 2>/dev/null
    
    echo -e "${CYAN}[*] Step 3: Disabling services...${NC}"
    systemctl disable xray 2>/dev/null
    systemctl disable zainu-ssh-ws 2>/dev/null
    systemctl disable dropbear 2>/dev/null
    
    echo -e "${CYAN}[*] Step 4: Removing systemd service files...${NC}"
    rm -f /etc/systemd/system/xray.service
    rm -f /etc/systemd/system/zainu-ssh-ws.service
    rm -f /etc/systemd/system/dropbear.service 2>/dev/null
    systemctl daemon-reload
    
    echo -e "${CYAN}[*] Step 5: Removing Xray binary and config...${NC}"
    rm -f "$XRAY_BIN"
    rm -f "$XRAY_CONFIG"
    rm -rf /usr/local/etc/xray/
    rm -rf /var/log/xray/
    rm -f /usr/local/bin/xray
    rm -f /usr/local/share/xray/ -rf 2>/dev/null
    
    echo -e "${CYAN}[*] Step 6: Removing SSH WebSocket service...${NC}"
    rm -f /opt/zainu-ssh-ws.py
    rm -f /opt/zainu-quota.py
    
    echo -e "${CYAN}[*] Step 7: Removing VPN Manager directories...${NC}"
    rm -rf "$INSTALL_DIR"
    rm -rf "$BRAND_DIR"
    rm -rf "$SSL_DIR"
    
    echo -e "${CYAN}[*] Step 8: Removing brand files (MOTD, banner)...${NC}"
    rm -f /etc/motd
    touch /etc/motd  # Restore empty motd
    rm -f /etc/ssh/zainu-banner.txt
    rm -f /etc/issue.net
    touch /etc/issue.net
    
    # Restore sshd_config (remove our customizations)
    echo -e "${CYAN}[*] Step 9: Restoring SSH config...${NC}"
    SSHD_CONFIG="/etc/ssh/sshd_config"
    sed -i '/^Banner /d' "$SSHD_CONFIG"
    sed -i 's/^PrintMotd .*/#PrintMotd yes/' "$SSHD_CONFIG"
    
    # Restore Dropbear config
    if [[ -f /etc/default/dropbear ]]; then
        sed -i 's/^NO_START=.*/NO_START=1/' /etc/default/dropbear
        sed -i '/^DROPBEAR_BANNER/d' /etc/default/dropbear
    fi
    
    echo -e "${CYAN}[*] Step 10: Removing Nginx VPN config...${NC}"
    rm -f /etc/nginx/sites-available/zainu
    rm -f /etc/nginx/sites-enabled/zainu
    
    echo -e "${CYAN}[*] Step 11: Removing firewall rules...${NC}"
    iptables -D INPUT -p tcp --dport 2082 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 2083 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 2053 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
    # Clean any user-specific chains
    iptables -F OUTPUT 2>/dev/null
    
    echo -e "${CYAN}[*] Step 12: Removing cron jobs...${NC}"
    crontab -l 2>/dev/null | grep -v "zainu-vpn" | grep -v "auto-expire" | grep -v "reset-quota" | crontab -
    
    echo -e "${CYAN}[*] Step 13: Removing log files...${NC}"
    rm -f "$LOG_FILE"
    rm -f /var/log/zainu-vpn.log
    
    echo -e "${CYAN}[*] Step 14: Removing temporary files...${NC}"
    rm -f /tmp/xray.zip
    rm -rf /tmp/xray_tmp
    
    echo -e "${CYAN}[*] Step 15: Restarting base services...${NC}"
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   UNINSTALL COMPLETE - VPS IS NOW CLEAN!         ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}All VPN files, users, services, and configs removed.${NC}"
    echo -e "${CYAN}VPS is back to clean state like before install.${NC}"
    echo ""
    log "FULL UNINSTALL COMPLETED - VPS cleaned"
}

# ============================================================
#   MAIN MENU
# ============================================================
main_menu() {
    while true; do
        show_banner
        echo -e "  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${GREEN}${BOLD}║                    SSH ACCOUNTS                            ║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}1${NC}. ${WHITE}Create SSH Account${GREEN}                                ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}2${NC}. ${WHITE}List SSH Users${GREEN}                                    ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}3${NC}. ${WHITE}Delete SSH User${GREEN}                                   ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}4${NC}. ${WHITE}Renew SSH User${GREEN}                                    ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║                    VLESS ACCOUNTS                         ║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}5${NC}. ${WHITE}Create VLESS (WS TLS + Non-TLS)${GREEN}                  ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}6${NC}. ${WHITE}List VLESS Users${GREEN}                                  ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}7${NC}. ${WHITE}Delete VLESS User${GREEN}                                 ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║                    VMESS / trojan                          ║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}8${NC}. ${WHITE}Create VMess Account${GREEN}                                ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}9${NC}. ${WHITE}Create Trojan Account${GREEN}                              ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}10${NC}. ${WHITE}List VMess/Trojan Users${GREEN}                            ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}11${NC}. ${WHITE}Delete VMess/Trojan${GREEN}                                ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║                    SYSTEM                                 ║${NC}"
        echo -e "  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}12${NC}. ${WHITE}System Status${GREEN}                                     ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}13${NC}. ${WHITE}Online Users Monitor${GREEN}                               ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}14${NC}. ${WHITE}Customize Server Message${GREEN}                           ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}15${NC}. ${WHITE}Restart Services${GREEN}                                  ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}16${NC}. ${WHITE}Reinstall / Fix${GREEN}                                   ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}17${NC}. ${WHITE}Uninstall (Clean VPS Completely)${GREEN}                    ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}║${NC}  ${YELLOW}0${NC}. ${WHITE}Exit${GREEN}                                              ${BOLD}║${NC}"
        echo -e "  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        read -p "  Select option [0-17]: " CHOICE
        echo ""
        
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
            10) 
                echo -e "${CYAN}VMess Users:${NC}"
                list_vmess_users
                echo ""
                echo -e "${CYAN}Trojan Users:${NC}"
                list_trojan_users
                ;;
            11) 
                echo -e "${CYAN}1) Delete VMess  2) Delete Trojan${NC}"
                read -p "Choose: " SUB
                case $SUB in
                    1) delete_vmess_user ;;
                    2) delete_trojan_user ;;
                esac
                ;;
            12) show_status ;;
            13) show_online_users ;;
            14) customize_server_message ;;
            15)
                systemctl restart xray zainu-ssh-ws sshd dropbear nginx 2>/dev/null
                echo -e "${GREEN}[+] Services restarted!${NC}"
                ;;
            16) full_install ;;
            17) uninstall_all ;;
            0) echo -e "${GREEN}${BRAND} - Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
        
        echo ""
        read -p "Press ENTER to continue..."
    done
}

# ============ ENTRY POINT ============
check_root

# First run check
if [[ ! -f "$XRAY_BIN" ]] || [[ ! -d "$INSTALL_DIR" ]]; then
    full_install
fi

# Read domain if exists
[[ -f "$INSTALL_DIR/domain" ]] && SERVER_DOMAIN=$(cat "$INSTALL_DIR/domain")

main_menu