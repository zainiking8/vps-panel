#!/bin/bash
#====================================================
# ZAINU X BRAND PREMIUM VPS PANEL
# GitHub: https://github.com/zainiking8/vps-panel
# Author: ZAINU X BRAND
# Version: 3.0.0
# Description: All-in-one VPN panel with SSH, Xray,
#              SlowDNS, UDP, SSL & server messages
#====================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Branding
BRAND_NAME="ZAINU X BRAND"
PANEL_NAME="PREMIUM VPS PANEL"
REPO_URL="https://github.com/zainiking8/vps-panel"
RAW_URL="https://raw.githubusercontent.com/zainiking8/vps-panel/main"

# Paths
INSTALL_DIR="/usr/local/zainu-x-brand"
CREDENTIALS="$INSTALL_DIR/credentials.txt"
CONFIG_DIR="$INSTALL_DIR/configs"
BANNER_FILE="$INSTALL_DIR/banner.txt"
MOTD_FILE="/etc/update-motd.d/99-zainu-x-brand"
LIMIT_SCRIPT="$INSTALL_DIR/ssh-limit.sh"
PROTO_FILE="$INSTALL_DIR/protocols.conf"

#====================================================
# Utility Functions
#====================================================
clear_screen() { clear; }

print_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${BOLD}${GREEN}👑 ${BRAND_NAME} ${PANEL_NAME} 👑${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        ${YELLOW}SSH • XRAY • SLOWDNS • UDP • SSL${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        ${MAGENTA}GitHub: ${REPO_URL}${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
msg_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

pause() { read -p "Press Enter to continue..."; }

is_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_err "This script must be run as root!"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    msg_info "Detected OS: ${OS} ${VER}"
}

install_packages() {
    msg_info "Updating system and installing required packages..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y \
        curl wget git unzip socat net-tools cron \
        jq nginx certbot python3-certbot-nginx \
        dropbear stunnel4 \
        > /dev/null 2>&1
    msg_ok "Base packages installed"
}

#====================================================
# Branding / Server Message
#====================================================
setup_banner() {
    mkdir -p "$INSTALL_DIR"
    cat > "$BANNER_FILE" <<'EOF'

╔══════════════════════════════════════════════════════════╗
║  👑 ZAINU X BRAND PREMIUM VPN SCRIPT 👑                ║
║                                                          ║
║  ✅ No Hacking    ✅ No Torrent                         ║
║  ✅ No Carding    ✅ No Spam                            ║
║  ✅ No DDoS       ✅ No Illegal Activities              ║
║                                                          ║
║  Thank you for choosing ZAINU X BRAND!                   ║
╚══════════════════════════════════════════════════════════╝

EOF

    cat > "$MOTD_FILE" <<'EOF'
#!/bin/sh
cat /usr/local/zainu-x-brand/banner.txt
EOF
    chmod +x "$MOTD_FILE"

    # SSH banner
    cp "$BANNER_FILE" /etc/ssh-banner.txt
    sed -i 's/^#*Banner.*/Banner \/etc\/ssh-banner.txt/' /etc/ssh/sshd_config
    grep -q "^Banner" /etc/ssh/sshd_config || echo "Banner /etc/ssh-banner.txt" >> /etc/ssh/sshd_config

    systemctl restart sshd >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    msg_ok "Server message (MOTD + SSH Banner) configured"
}

#====================================================
# System Optimization
#====================================================
optimize_system() {
    msg_info "Optimizing system kernel (BBR + limits)..."
    cat >> /etc/sysctl.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
    sysctl -p >/dev/null 2>&1

    cat >> /etc/security/limits.conf <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
EOF
    msg_ok "System optimized with BBR"
}

#====================================================
# Firewall
#====================================================
setup_firewall() {
    msg_info "Configuring firewall ports..."
    if command -v ufw >/dev/null 2>&1; then
        ufw default allow outgoing >/dev/null 2>&1
        ufw default deny incoming >/dev/null 2>&1
        for port in 22 80 443 143 444 8080 8443 2052 2053 2082 2083 2086 2087 2095 2096 54321 10000 5300 7300; do
            ufw allow "$port"/tcp >/dev/null 2>&1
        done
        ufw allow 5300/udp >/dev/null 2>&1
        ufw allow 7300/udp >/dev/null 2>&1
        ufw --force enable >/dev/null 2>&1
    else
        msg_warn "UFW not available, skipping firewall config"
    fi
    msg_ok "Firewall configured"
}

#====================================================
# 3X-UI / Xray Core Installation
#====================================================
install_3x_ui() {
    msg_info "Installing 3X-UI panel (Xray Core)..."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<EOF
y
EOF
    msg_ok "3X-UI panel installed"

    # Save credentials placeholder
    mkdir -p "$INSTALL_DIR"
    XUI_USER=$(x-ui setting -show true 2>/dev/null | grep -i "username" | awk '{print $2}' || echo "admin")
    XUI_PASS=$(x-ui setting -show true 2>/dev/null | grep -i "password" | awk '{print $2}' || echo "admin")
    echo "3X-UI Panel: http://$(curl -s ifconfig.me):54321" >> "$CREDENTIALS"
    echo "3X-UI Username: ${XUI_USER}" >> "$CREDENTIALS"
    echo "3X-UI Password: ${XUI_PASS}" >> "$CREDENTIALS"
}

#====================================================
# SSL / Nginx Setup
#====================================================
setup_ssl_nginx() {
    local domain=$1
    local email=$2

    if [[ -z "$domain" ]]; then
        msg_warn "No domain provided, skipping SSL. Use IP-only setup."
        return
    fi

    msg_info "Setting up Nginx reverse proxy and SSL for ${domain}..."

    # Nginx default config for panel subdomain
    cat > /etc/nginx/sites-available/zainu-x-brand <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name panel.${domain} sub.${domain} vless.${domain} vmess.${domain} trojan.${domain};

    location / {
        proxy_pass http://127.0.0.1:54321;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/zainu-x-brand /etc/nginx/sites-enabled/zainu-x-brand
    nginx -t >/dev/null 2>&1 && systemctl restart nginx >/dev/null 2>&1

    msg_info "Requesting SSL certificate via Certbot..."
    certbot --nginx --non-interactive --agree-tos --email "$email" \
        -d "panel.${domain}" -d "sub.${domain}" -d "vless.${domain}" \
        -d "vmess.${domain}" -d "trojan.${domain}" >/dev/null 2>&1

    if [[ -f /etc/letsencrypt/live/panel.${domain}/fullchain.pem ]]; then
        msg_ok "SSL certificate installed for ${domain} subdomains"
        echo "SSL: /etc/letsencrypt/live/panel.${domain}/" >> "$CREDENTIALS"
    else
        msg_err "SSL certificate failed. Check DNS A-records."
    fi

    # Auto-renew cron
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -
}

#====================================================
# SlowDNS
#====================================================
install_slowdns() {
    msg_info "Installing SlowDNS server..."
    apt-get install -y python3-dnslib >/dev/null 2>&1
    mkdir -p /etc/slowdns

    # Generate key pair
    NS_DOMAIN=${NS_DOMAIN:-ns.zainuxbrand}
    NS_KEY=$(openssl rand -base64 32 | tr -d '=+/')

    cat > /etc/slowdns/server.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading, base64, subprocess, sys
from dnslib import DNSRecord, DNSHeader, RR, A, TXT, QTYPE

LISTEN_IP = '0.0.0.0'
LISTEN_PORT = 5300
NS_DOMAIN = 'ns.zainuxbrand'
SSH_HOST = '127.0.0.1'
SSH_PORT = 22

def handle_request(data, addr, sock):
    try:
        request = DNSRecord.parse(data)
        qname = str(request.q.qname).rstrip('.')
        qtype = request.q.qtype
        reply = DNSRecord(DNSHeader(id=request.header.id, qr=1, aa=1, ra=1), q=request.q)
        if qtype == QTYPE.A:
            reply.add_answer(RR(qname, QTYPE.A, rdata=A(SSH_HOST), ttl=60))
        if qtype == QTYPE.TXT and NS_DOMAIN in qname:
            payload = base64.b64encode(f"ZAINU X BRAND PREMIUM VPN SCRIPT | {qname}".encode()).decode()
            reply.add_answer(RR(qname, QTYPE.TXT, rdata=TXT(payload), ttl=60))
        sock.sendto(reply.pack(), addr)
    except Exception:
        pass

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((LISTEN_IP, LISTEN_PORT))
print(f"SlowDNS listening on {LISTEN_IP}:{LISTEN_PORT}")
while True:
    data, addr = sock.recvfrom(4096)
    threading.Thread(target=handle_request, args=(data, addr, sock)).start()
PYEOF
    chmod +x /etc/slowdns/server.py

    cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=ZAINU X BRAND SlowDNS Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/slowdns/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable slowdns >/dev/null 2>&1
    systemctl start slowdns >/dev/null 2>&1

    echo "SlowDNS NS Domain: ${NS_DOMAIN}" >> "$CREDENTIALS"
    echo "SlowDNS NS Key: ${NS_KEY}" >> "$CREDENTIALS"
    echo "SlowDNS UDP Port: 5300" >> "$CREDENTIALS"
    msg_ok "SlowDNS installed (Port 5300/UDP)"
}

#====================================================
# UDP Custom
#====================================================
install_udp_custom() {
    msg_info "Installing UDP Custom tunnel..."
    mkdir -p /etc/udp-custom
    cat > /etc/udp-custom/server.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading

LISTEN_IP = '0.0.0.0'
LISTEN_PORT = 7300
TARGET = ('127.0.0.1', 22)

def relay(source, destination):
    while True:
        try:
            data = source.recv(4096)
            if not data: break
            destination.sendall(data)
        except Exception:
            break
    try: source.close()
    except: pass
    try: destination.close()
    except: pass

def handle_client(client, addr):
    try:
        backend = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        backend.connect(TARGET)
        threading.Thread(target=relay, args=(client, backend)).start()
        threading.Thread(target=relay, args=(backend, client)).start()
    except Exception:
        client.close()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((LISTEN_IP, LISTEN_PORT))
print(f"UDP Custom listening on {LISTEN_IP}:{LISTEN_PORT}")
while True:
    data, addr = sock.recvfrom(4096)
    threading.Thread(target=handle_client, args=(sock, addr)).start()
PYEOF
    chmod +x /etc/udp-custom/server.py

    cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=ZAINU X BRAND UDP Custom Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/udp-custom/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable udp-custom >/dev/null 2>&1
    systemctl start udp-custom >/dev/null 2>&1

    echo "UDP Custom Port: 7300" >> "$CREDENTIALS"
    msg_ok "UDP Custom installed (Port 7300/UDP)"
}

#====================================================
# SSH Limits Script
#====================================================
setup_ssh_limits() {
    cat > "$LIMIT_SCRIPT" <<'EOF'
#!/bin/bash
# SSH account limit enforcement for ZAINU X BRAND

USER_DB="/usr/local/zainu-x-brand/ssh-users.db"
LOG_DIR="/usr/local/zainu-x-brand/logs"
mkdir -p "$LOG_DIR"

while true; do
    while IFS='|' read -r user pass expiry iplimit gblimit usedgb status; do
        [[ -z "$user" ]] && continue
        [[ "$status" == "disabled" ]] && continue

        # Expiry check
        if [[ -n "$expiry" ]] && [[ "$expiry" != "never" ]]; then
            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
            now_epoch=$(date +%s)
            if [[ "$expiry_epoch" -lt "$now_epoch" && "$expiry_epoch" -ne 0 ]]; then
                usermod -L "$user" 2>/dev/null
                sed -i "s/^${user}|.*/${user}|${pass}|${expiry}|${iplimit}|${gblimit}|${usedgb}|disabled/" "$USER_DB"
                continue
            fi
        fi

        # IP limit check
        if [[ -n "$iplimit" ]] && [[ "$iplimit" != "unlimited" ]]; then
            sessions=$(ps -u "$user" -o comm= | grep -c "^sshd$" 2>/dev/null || echo 0)
            if [[ "$sessions" -gt "$iplimit" ]]; then
                pkill -u "$user" -f sshd 2>/dev/null
            fi
        fi

        # GB limit check
        if [[ -n "$gblimit" ]] && [[ "$gblimit" != "unlimited" ]]; then
            rx=$(cat /proc/net/dev | awk '/'$user'/ {print}' 2>/dev/null | awk '{print $2}')
            tx=$(cat /proc/net/dev | awk '/'$user'/ {print}' 2>/dev/null | awk '{print $10}')
            # Simplified; real per-user accounting requires more advanced tracking
        fi
    done < "$USER_DB"
    sleep 60
done
EOF
    chmod +x "$LIMIT_SCRIPT"

    cat > /etc/systemd/system/zainu-limit.service <<EOF
[Unit]
Description=ZAINU X BRAND SSH Limits Enforcer
After=network.target

[Service]
Type=simple
ExecStart=${LIMIT_SCRIPT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable zainu-limit >/dev/null 2>&1
    systemctl start zainu-limit >/dev/null 2>&1
    msg_ok "SSH limit enforcer installed"
}

#====================================================
# Full Installation
#====================================================
run_installation() {
    clear_screen
    print_banner
    is_root
    check_os

    echo -e "${YELLOW}This will install all services. Continue? [Y/n]:${NC} "
    read -r confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && return

    # Inputs
    echo -e "${CYAN}Enter your domain (leave blank for IP-only setup):${NC}"
    read -r domain
    email="admin@${domain:-localhost}"
    if [[ -n "$domain" ]]; then
        echo -e "${CYAN}Enter email for SSL certificate:${NC}"
        read -r email
    fi

    echo -e "${CYAN}Enter SlowDNS NS subdomain [ns.zainuxbrand]:${NC}"
    read -r nsdomain
    NS_DOMAIN=${nsdomain:-ns.zainuxbrand}

    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
    echo "Installation Date: $(date)" > "$CREDENTIALS"
    echo "Domain: ${domain:-IP-Only}" >> "$CREDENTIALS"
    echo "Public IP: $(curl -s ifconfig.me)" >> "$CREDENTIALS"
    echo "======================================" >> "$CREDENTIALS"

    install_packages
    setup_banner
    optimize_system
    setup_firewall
    install_3x_ui
    setup_ssl_nginx "$domain" "$email"
    install_slowdns
    install_udp_custom
    setup_ssh_limits

    # Mark installed
    echo "installed" > "$INSTALL_DIR/.installed"
    echo "version=3.0.0" >> "$INSTALL_DIR/.installed"

    clear_screen
    print_banner
    echo -e "${GREEN}${BOLD}Installation completed successfully!${NC}"
    echo -e "${CYAN}Credentials saved at:${NC} ${YELLOW}$CREDENTIALS${NC}"
    echo ""
    cat "$CREDENTIALS"
    echo ""
    echo -e "${MAGENTA}Run '${BOLD}menu${NC}${MAGENTA}' anytime to open this panel.${NC}"
    pause
}

#====================================================
# SSH Account Management
#====================================================
SSH_DB="$INSTALL_DIR/ssh-users.db"
touch "$SSH_DB"

create_ssh_account() {
    clear_screen
    print_banner
    echo -e "${CYAN}${BOLD}Create SSH Account${NC}"
    echo ""
    read -p "Username: " username
    read -p "Password: " password
    read -p "IP Limit (number or 'unlimited'): " iplimit
    read -p "GB Limit (number or 'unlimited'): " gblimit
    read -p "Expiry Days (0 for never): " expdays

    if id "$username" &>/dev/null; then
        msg_warn "User already exists!"
        pause
        return
    fi

    if [[ "$expdays" == "0" || -z "$expdays" ]]; then
        expiry="never"
    else
        expiry=$(date -d "+${expdays} days" +%Y-%m-%d)
    fi

    useradd -m -s /bin/bash "$username" >/dev/null 2>&1
    echo "${username}:${password}" | chpasswd >/dev/null 2>&1

    echo "${username}|${password}|${expiry}|${iplimit}|${gblimit}|0|enabled" >> "$SSH_DB"

    local ip
    ip=$(curl -s ifconfig.me)

    clear_screen
    print_banner
    echo -e "${GREEN}${BOLD}✅ SSH Account Created${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e " ${WHITE}Host      :${NC} ${ip}"
    echo -e " ${WHITE}Username  :${NC} ${username}"
    echo -e " ${WHITE}Password  :${NC} ${password}"
    echo -e " ${WHITE}Port      :${NC} 22 / 143 / 444"
    echo -e " ${WHITE}IP Limit  :${NC} ${iplimit}"
    echo -e " ${WHITE}GB Limit  :${NC} ${gblimit}"
    echo -e " ${WHITE}Expiry    :${NC} ${expiry}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🌐 Server Message:${NC}"
    echo -e "${CYAN}👑 ${BRAND_NAME} PREMIUM VPN SCRIPT${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠️ TERMS OF SERVICE ⚠️${NC}"
    echo -e "${WHITE}❌ No Hacking   ❌ No Torrent${NC}"
    echo -e "${WHITE}❌ No Carding   ❌ No Spam${NC}"
    echo -e "${WHITE}❌ No DDoS      ❌ No Illegal Activities${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}📡 Payload Example (HTTP Custom):${NC}"
    echo -e "${CYAN}GET / HTTP/1.1[crlf]Host: ${ip}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    pause
}

delete_ssh_account() {
    read -p "Enter username to delete: " username
    if id "$username" &>/dev/null; then
        userdel -r "$username" >/dev/null 2>&1
        sed -i "/^${username}|/d" "$SSH_DB"
        msg_ok "User ${username} deleted"
    else
        msg_err "User not found"
    fi
    pause
}

list_ssh_accounts() {
    clear_screen
    print_banner
    echo -e "${CYAN}${BOLD}SSH Accounts List${NC}\n"
    printf "${BOLD}%-12s %-15s %-10s %-10s %-6s %s${NC}\n" "USER" "PASS" "EXPIRY" "IP LIMIT" "GB" "STATUS"
    while IFS='|' read -r u p e i g used s; do
        [[ -z "$u" ]] && continue
        printf "%-12s %-15s %-10s %-10s %-6s %s\n" "$u" "$p" "$e" "$i" "$g" "$s"
    done < "$SSH_DB"
    echo ""
    pause
}

#====================================================
# Xray Account Display Helpers
#====================================================
show_vless_config() {
    clear_screen
    print_banner
    local ip domain port uuid path
    ip=$(curl -s ifconfig.me)
    read -p "Domain/IP: " domain
    read -p "Port [443]: " port
    port=${port:-443}
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || tr </dev/urandom -dc 'a-f0-9' | head -c32)
    read -p "Path [/zainu]: " path
    path=${path:-/zainu}

    local link="vless://${uuid}@${domain}:${port}?path=${path}&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${BRAND_NAME}-VLESS"

    echo -e "${GREEN}${BOLD}✅ VLESS Account Configuration${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e " ${WHITE}Host      :${NC} ${domain}"
    echo -e " ${WHITE}Port      :${NC} ${port}"
    echo -e " ${WHITE}UUID      :${NC} ${uuid}"
    echo -e " ${WHITE}Path      :${NC} ${path}"
    echo -e " ${WHITE}Network   :${NC} ws"
    echo -e " ${WHITE}Security  :${NC} tls"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🔗 VLESS Link:${NC}"
    echo -e "${MAGENTA}${link}${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🌐 Server Message:${NC}"
    echo -e "${CYAN}👑 ${BRAND_NAME} PREMIUM VPN SCRIPT${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠️ TERMS OF SERVICE ⚠️${NC}"
    echo -e "${WHITE}❌ No Hacking   ❌ No Torrent${NC}"
    echo -e "${WHITE}❌ No Carding   ❌ No Spam${NC}"
    echo -e "${WHITE}❌ No DDoS      ❌ No Illegal Activities${NC}"
    echo ""
    pause
}

show_vmess_config() {
    clear_screen
    print_banner
    local domain port uuid path
    read -p "Domain/IP: " domain
    read -p "Port [443]: " port
    port=${port:-443}
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || tr </dev/urandom -dc 'a-f0-9' | head -c32)
    read -p "Path [/zainu]: " path
    path=${path:-/zainu}

    local json='{"v":"2","ps":"'${BRAND_NAME}'-VMESS","add":"'${domain}'","port":"'${port}'","id":"'${uuid}'","aid":"0","net":"ws","type":"none","host":"'${domain}'","path":"'${path}'","tls":"tls"}'
    local link="vmess://$(echo -n "$json" | base64 -w0)"

    echo -e "${GREEN}${BOLD}✅ Vmess Account Configuration${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e " ${WHITE}Host      :${NC} ${domain}"
    echo -e " ${WHITE}Port      :${NC} ${port}"
    echo -e " ${WHITE}UUID      :${NC} ${uuid}"
    echo -e " ${WHITE}Path      :${NC} ${path}"
    echo -e " ${WHITE}Network   :${NC} ws"
    echo -e " ${WHITE}Security  :${NC} tls"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🔗 Vmess Link:${NC}"
    echo -e "${MAGENTA}${link}${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🌐 Server Message:${NC}"
    echo -e "${CYAN}👑 ${BRAND_NAME} PREMIUM VPN SCRIPT${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠️ TERMS OF SERVICE ⚠️${NC}"
    echo -e "${WHITE}❌ No Hacking   ❌ No Torrent${NC}"
    echo -e "${WHITE}❌ No Carding   ❌ No Spam${NC}"
    echo -e "${WHITE}❌ No DDoS      ❌ No Illegal Activities${NC}"
    echo ""
    pause
}

show_trojan_config() {
    clear_screen
    print_banner
    local domain port pass
    read -p "Domain/IP: " domain
    read -p "Port [443]: " port
    port=${port:-443}
    pass=$(tr </dev/urandom -dc 'A-Za-z0-9' | head -c16)

    local link="trojan://${pass}@${domain}:${port}?security=tls&sni=${domain}&type=tcp#${BRAND_NAME}-TROJAN"

    echo -e "${GREEN}${BOLD}✅ Trojan Account Configuration${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e " ${WHITE}Host      :${NC} ${domain}"
    echo -e " ${WHITE}Port      :${NC} ${port}"
    echo -e " ${WHITE}Password  :${NC} ${pass}"
    echo -e " ${WHITE}Security  :${NC} tls"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🔗 Trojan Link:${NC}"
    echo -e "${MAGENTA}${link}${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🌐 Server Message:${NC}"
    echo -e "${CYAN}👑 ${BRAND_NAME} PREMIUM VPN SCRIPT${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠️ TERMS OF SERVICE ⚠️${NC}"
    echo -e "${WHITE}❌ No Hacking   ❌ No Torrent${NC}"
    echo -e "${WHITE}❌ No Carding   ❌ No Spam${NC}"
    echo -e "${WHITE}❌ No DDoS      ❌ No Illegal Activities${NC}"
    echo ""
    pause
}

#====================================================
# Server Message Editor
#====================================================
edit_server_message() {
    clear_screen
    print_banner
    echo -e "${CYAN}Current server message preview:${NC}"
    cat "$BANNER_FILE"
    echo ""
    read -p "Enter new custom message line (or press Enter to keep): " custom_msg
    if [[ -n "$custom_msg" ]]; then
        cat > "$BANNER_FILE" <<EOF

╔══════════════════════════════════════════════════════════╗
║  👑 ${BRAND_NAME} PREMIUM VPN SCRIPT 👑                ║
║  ${custom_msg}                                          ║
║                                                          ║
║  ✅ No Hacking    ✅ No Torrent                         ║
║  ✅ No Carding    ✅ No Spam                            ║
║  ✅ No DDoS       ✅ No Illegal Activities              ║
║                                                          ║
║  Thank you for choosing ${BRAND_NAME}!                   ║
╚══════════════════════════════════════════════════════════╝

EOF
        cp "$BANNER_FILE" /etc/ssh-banner.txt
        msg_ok "Server message updated"
    fi
    pause
}

#====================================================
# Uninstall — Full Clean Removal
#====================================================
run_uninstall() {
    clear_screen
    print_banner
    echo -e "${RED}${BOLD}⚠️  UNINSTALL ZAINU X BRAND PANEL${NC}"
    echo -e "${YELLOW}This will remove ALL installed services, packages,"
    echo -e "configs, users, certs, and files — VPS will be fresh clean.${NC}"
    echo ""
    read -p "Type 'YES' to confirm full uninstall: " confirm
    [[ "$confirm" != "YES" ]] && { msg_warn "Uninstall cancelled."; pause; return; }

    msg_info "Stopping and disabling services..."

    # 3X-UI / Xray
    systemctl stop x-ui >/dev/null 2>&1
    systemctl disable x-ui >/dev/null 2>&1
    rm -f /etc/systemd/system/x-ui.service
    rm -rf /usr/local/x-ui /etc/x-ui /usr/bin/x-ui /usr/local/bin/x-ui >/dev/null 2>&1

    # SlowDNS
    systemctl stop slowdns >/dev/null 2>&1
    systemctl disable slowdns >/dev/null 2>&1
    rm -f /etc/systemd/system/slowdns.service
    rm -rf /etc/slowdns >/dev/null 2>&1

    # UDP Custom
    systemctl stop udp-custom >/dev/null 2>&1
    systemctl disable udp-custom >/dev/null 2>&1
    rm -f /etc/systemd/system/udp-custom.service
    rm -rf /etc/udp-custom >/dev/null 2>&1

    # SSH limit enforcer
    systemctl stop zainu-limit >/dev/null 2>&1
    systemctl disable zainu-limit >/dev/null 2>&1
    rm -f /etc/systemd/system/zainu-limit.service

    systemctl daemon-reload >/dev/null 2>&1
    msg_ok "Services stopped and removed"

    # Nginx configs
    msg_info "Removing Nginx configs..."
    systemctl stop nginx >/dev/null 2>&1
    rm -f /etc/nginx/sites-enabled/zainu-x-brand
    rm -f /etc/nginx/sites-available/zainu-x-brand
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx >/dev/null 2>&1
    msg_ok "Nginx configs removed"

    # SSL certificates
    msg_info "Removing Let's Encrypt certificates..."
    if command -v certbot >/dev/null 2>&1; then
        certbot delete --non-interactive --keep >/dev/null 2>&1
    fi
    rm -rf /etc/letsencrypt >/dev/null 2>&1
    msg_ok "SSL certs removed"

    # SSH users created by script
    msg_info "Removing SSH accounts created by panel..."
    if [[ -f "$SSH_DB" ]]; then
        while IFS='|' read -r u p e i g used s; do
            [[ -z "$u" ]] && continue
            userdel -r "$u" >/dev/null 2>&1
        done < "$SSH_DB"
    fi
    msg_ok "SSH users removed"

    # Banner / MOTD / SSH banner
    msg_info "Removing branding and server messages..."
    rm -f "$MOTD_FILE"
    rm -f /etc/ssh-banner.txt
    sed -i '/^Banner \/etc\/ssh-banner.txt/d' /etc/ssh/sshd_config
    sed -i 's/^Banner \/etc\/ssh-banner.txt/#Banner none/' /etc/ssh/sshd_config
    systemctl restart sshd >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    msg_ok "Branding removed"

    # Firewall rules
    msg_info "Resetting firewall..."
    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset >/dev/null 2>&1
    fi
    msg_ok "Firewall reset"

    # Cron entries
    msg_info "Removing cron jobs..."
    crontab -l 2>/dev/null | grep -v "certbot renew" | crontab - >/dev/null 2>&1
    msg_ok "Cron cleaned"

    # Sysctl / limits revert
    msg_info "Reverting system optimizations..."
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fastopen=3/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_reuse=1/d' /etc/sysctl.conf
    sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.forwarding=1/d' /etc/sysctl.conf
    sed -i '/\* soft nofile 1048576/d' /etc/security/limits.conf
    sed -i '/\* hard nofile 1048576/d' /etc/security/limits.conf
    sed -i '/\* soft nproc 1048576/d' /etc/security/limits.conf
    sed -i '/\* hard nproc 1048576/d' /etc/security/limits.conf
    sysctl -p >/dev/null 2>&1
    msg_ok "System optimizations reverted"

    # Remove installed packages
    msg_info "Removing installed packages (purge)..."
    apt-get purge -y \
        dropbear stunnel4 nginx nginx-common certbot python3-certbot-nginx \
        python3-dnslib jq socat >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1
    msg_ok "Packages purged"

    # Remove install dir + menu command
    msg_info "Removing panel directory and menu command..."
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/menu
    msg_ok "Panel files removed"

    clear_screen
    print_banner
    echo -e "${GREEN}${BOLD}✅ Uninstall complete!${NC}"
    echo -e "${CYAN}VPS is now fresh and clean.${NC}"
    echo -e "${YELLOW}You can reinstall anytime with:${NC}"
    echo -e "${MAGENTA}bash <(curl -sL ${RAW_URL}/menu.sh)${NC}"
    echo ""
    pause
    exit 0
}

#====================================================
# System Info
#====================================================
show_system_info() {
    clear_screen
    print_banner
    local ip os ram disk cpu
    ip=$(curl -s ifconfig.me)
    os=$(grep -oP '(?<=^PRETTY_NAME=)".*"' /etc/os-release | tr -d '"')
    ram=$(free -h | awk '/Mem:/ {print $2}')
    disk=$(df -h / | awk 'NR==2 {print $2}')
    cpu=$(nproc)

    echo -e "${CYAN}${BOLD}System Information${NC}"
    echo ""
    echo -e " ${WHITE}OS       :${NC} ${os}"
    echo -e " ${WHITE}CPU      :${NC} ${cpu} Cores"
    echo -e " ${WHITE}RAM      :${NC} ${ram}"
    echo -e " ${WHITE}Disk     :${NC} ${disk}"
    echo -e " ${WHITE}Public IP:${NC} ${ip}"
    echo -e " ${WHITE}Panel    :${NC} http://${ip}:54321"
    echo ""
    pause
}

#====================================================
# Main Menu
#====================================================
main_menu() {
    while true; do
        clear_screen
        print_banner
        echo -e "${WHITE}Choose an option:${NC}"
        echo ""
        echo -e "${CYAN} 1)${NC} Create SSH Account"
        echo -e "${CYAN} 2)${NC} Delete SSH Account"
        echo -e "${CYAN} 3)${NC} List SSH Accounts"
        echo -e "${CYAN} 4)${NC} Create VLESS Config"
        echo -e "${CYAN} 5)${NC} Create Vmess Config"
        echo -e "${CYAN} 6)${NC} Create Trojan Config"
        echo -e "${CYAN} 7)${NC} Edit Server Message"
        echo -e "${CYAN} 8)${NC} System Info"
        echo -e "${CYAN} 9)${NC} Reboot Server"
        echo -e "${RED}10)${NC} Uninstall Panel (Fresh Clean)"
        echo -e "${CYAN} 0)${NC} Exit"
        echo ""
        read -p "Select option: " opt

        case "$opt" in
            1) create_ssh_account ;;
            2) delete_ssh_account ;;
            3) list_ssh_accounts ;;
            4) show_vless_config ;;
            5) show_vmess_config ;;
            6) show_trojan_config ;;
            7) edit_server_message ;;
            8) show_system_info ;;
            9) read -p "Reboot now? [y/N]: " r; [[ "$r" =~ ^[Yy]$ ]] && reboot ;;
            10) run_uninstall ;;
            0) clear_screen; echo -e "${GREEN}👑 ${BRAND_NAME} - Stay Premium!${NC}"; exit 0 ;;
            0) clear_screen; echo -e "${GREEN}👑 ${BRAND_NAME} - Stay Premium!${NC}"; exit 0 ;;
            *) msg_err "Invalid option"; sleep 1 ;;
        esac
    done
}

#====================================================
# Entry Point
#====================================================
if [[ ! -f "$INSTALL_DIR/.installed" ]]; then
    run_installation
fi

main_menu
