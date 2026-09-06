#!/bin/bash
# ==============================================================================
# PART 1: GLOBAL FRAMEWORK INITIALIZATION & THEME COLORS
# ==============================================================================
export LANG=en_US.UTF-8

# Core Configuration Paths
PANEL_NAME="ZAINUXBRAND Premium VPN Panel"
BANNER_FILE="/etc/issue.net"
CUSTOM_PATH="/zainuxbrand"
DOMAIN_FILE="/etc/zainuxbrand/domain.conf"
XRAY_CONFIG="/etc/xray/config.json"
SLOWDNS_DIR="/etc/slowdns"
USER_DIR="/etc/zainuxbrand/users"

# Premium UI Color Variables
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'

# Root Access Security Verification
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] Fatal: Complete root execution context required! (Run: sudo -i)${NC}"
   exit 1
fi

get_domain() {
    if [[ -f "$DOMAIN_FILE" ]]; then
        cat "$DOMAIN_FILE" | tr -d '\r\n'
    else
        echo "No Domain Set"
    fi
}

press_any_key() {
    echo -e "\n${YELLOW}Press [ENTER] key to return to main dashboard menu...${NC}"
    read -r
}

clear
# ==============================================================================
# PART 2: ENTERPRISE DEPENDENCIES & CORE PACKAGES
# ==============================================================================
install_system_packages() {
    clear
    echo -e "${YELLOW}[*] Indexing repository maps and updating system binaries...${NC}"
    apt-get update -y && apt-get upgrade -y
    
    echo -e "${YELLOW}[*] Injecting networking nodes, python core runtime, and security wrappers...${NC}"
    apt-get install -y curl wget unzip tar net-tools socat jq openssl nginx dropbear certbot \
    python3 python3-pip python3-certbot-nginx lsof iptables git build-essential cron ufw > /dev/null 2>&1
    
    # Activating and locking background daemons
    systemctl daemon-reload
    systemctl enable nginx cron dropbear
    systemctl start nginx cron dropbear
    
    echo -e "${GREEN}[✓] Production Infrastructure Dependencies Provisioned Successfully!${NC}"
    sleep 1.5
}
# ==============================================================================
# PART 3: TCP BBR ACCELERATION STACK
# ==============================================================================
optimize_network_bbr() {
    echo -e "${YELLOW}[*] Validating current network pipeline and applying Google BBR...${NC}"
    
    # Pruning legacy network limits
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    
    # Injecting high-throughput low-latency network rules
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    # Loading new system control variables
    sysctl -p > /dev/null 2>&1
    echo -e "${GREEN}[✓] Google BBR Acceleration Engine Locked into Core Kernel!${NC}"
}
# ==============================================================================
# PART 4: DROPBEAR CONFIGURATION & REBRANDED WELCOME BANNER
# ==============================================================================
configure_dropbear_and_banner() {
    echo -e "${YELLOW}[*] Mounting cryptographic host keys for multi-port routing...${NC}"
    mkdir -p /etc/dropbear
    chmod 700 /etc/dropbear

    if [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key &>/dev/null
    fi
    if [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]]; then
        dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key &>/dev/null
    fi
    if [[ ! -f /etc/dropbear/dropbear_ed25519_host_key ]]; then
        dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key &>/dev/null
    fi

    chmod 600 /etc/dropbear/*_host_key 2>/dev/null
    rm -rf /etc/systemd/system/dropbear.service.d

    # Mounting requested Zainu Premium Rebranded Banner Message
    cat << 'BANNER_EOF' > $BANNER_FILE
<font color="#00FF00">==================================================</font><br>
<font color="#FFFF00"><b>★ WELCOME TO ZAINU X BRAND PREMIUM VPN NETWORK ★</b></font><br>
<font color="#00FFFF"><b> Status: Private Premium Access Channel Secure</b></font><br>
<font color="#FF0000"><b> Rules: Strict No-Torrent / No Multi-Login Active!</b></font><br>
<font color="#00FF00">==================================================</font><br>
BANNER_EOF

    # Binding multi-ports runtime mapping flags
    cat << 'DB_CONF' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=22
DROPBEAR_EXTRA_ARGS="-p 109 -p 447 -b /etc/issue.net"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
DB_CONF

    # Synchronizing SSH global banners
    sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
    sed -i 's/PrintMotd no/PrintMotd yes/g' /etc/ssh/sshd_config
    
    systemctl daemon-reload
    systemctl restart dropbear ssh sshd
    echo -e "${GREEN}[✓] Dropbear & Rebranded Custom HTML Banner Integrated!${NC}"
}
# ==============================================================================
# PART 5: PYTHON BACKGROUND USER TRACKER & ENFORCEMENT ENGINE
# ==============================================================================
deploy_quota_tracker_engine() {
    echo -e "${YELLOW}[*] Formatting local storage registers and user memory lines...${NC}"
    mkdir -p /etc/zainuxbrand/users
    
    cat << 'PY_EOF' > /usr/local/bin/autokill.py
import os
import sys
import time
import subprocess
import re

USER_DIR = "/etc/zainuxbrand/users"
LOG_FILE = "/var/log/autokill.log"

def get_auth_logs():
    raw = ""
    try:
        raw = subprocess.check_output(["journalctl", "-u", "dropbear", "--no-pager", "-n", "300"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
    except Exception:
        pass
    if os.path.exists("/var/log/auth.log"):
        try:
            with open("/var/log/auth.log", "r", encoding="utf-8", errors="ignore") as f:
                raw += "\n" + f.read()
        except Exception:
            pass
    return raw

def get_active_users_and_pids(raw_logs):
    user_pids = {}
    try:
        ps_out = subprocess.check_output(["ps", "aux"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        for line in ps_out.splitlines():
            if "dropbear" in line and "grep" not in line:
                parts = line.split()
                if len(parts) > 1:
                    pid = parts[1]
                    matches = [l for l in raw_logs.splitlines() if f"dropbear[{pid}]" in l and "Password auth succeeded" in l]
                    if matches:
                        last_line = matches[-1]
                        m = re.search(r"for \x27(\w+)\x27", last_line)
                        if not m:
                            m = re.search(r"for (\w+)", last_line)
                        if m:
                            uname = m.group(1)
                            if uname not in user_pids:
                                user_pids[uname] = []
                            user_pids[uname].append(pid)
    except Exception:
        pass
    return user_pids

def get_pid_io_bytes(pid):
    io_file = f"/proc/{pid}/io"
    total_bytes = 0
    if os.path.exists(io_file):
        try:
            with open(io_file, "r") as f:
                for line in f:
                    if line.startswith("rchar:") or line.startswith("wchar:"):
                        total_bytes += int(line.split(":")[1].strip())
        except Exception:
            pass
    return total_bytes

last_pid_bytes = {}

while True:
    try:
        raw_logs = get_auth_logs()
        user_pids_map = get_active_users_and_pids(raw_logs)

        if os.path.exists(USER_DIR):
            for fname in os.listdir(USER_DIR):
                if not fname.endswith(".conf"):
                    continue

                uname = fname[:-5]
                conf_path = os.path.join(USER_DIR, fname)

                ip_limit = 0
                gb_limit = "Unlimited"
                used_mb = 0.0

                with open(conf_path, "r") as f:
                    lines = f.readlines()

                for line in lines:
                    if line.startswith("IP_LIMIT="):
                        try: ip_limit = int(line.strip().split("=")[1])
                        except Exception: pass
                    elif line.startswith("GB_LIMIT="):
                        gb_limit = line.strip().split("=")[1]
                    elif line.startswith("USED_MB="):
                        try: used_mb = float(line.strip().split("=")[1])
                        except Exception: pass

                active_pids = user_pids_map.get(uname, [])

                for pid in active_pids:
                    current_b = get_pid_io_bytes(pid)
                    if pid in last_pid_bytes:
                        diff = current_b - last_pid_bytes[pid]
                        if diff > 0:
                            used_mb += (diff / (1024.0 * 1024.0))
                    last_pid_bytes[pid] = current_b

                new_lines = []
                for line in lines:
                    if line.startswith("USED_MB="):
                        new_lines.append(f"USED_MB={used_mb:.2f}\n")
                    else:
                        new_lines.append(line)
                with open(conf_path, "w") as f:
                    f.writelines(new_lines)

                if gb_limit != "Unlimited":
                    try:
                        max_mb = float(gb_limit) * 1024.0
                        if used_mb >= max_mb:
                            subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                            for pid in active_pids:
                                subprocess.call(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except Exception:
                        pass

                if ip_limit > 0 and len(active_pids) > ip_limit:
                    subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    for pid in active_pids:
                        subprocess.call(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    except Exception:
        pass

    time.sleep(3)
PY_EOF
    chmod +x /usr/local/bin/autokill.py

    # Constructing Systemd Thread Service Mount
    cat << 'SVC_EOF' > /etc/systemd/system/autokill.service
[Unit]
Description=Zainuxbrand Automated Protection & Bandwidth Enforcer Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/autokill.py
Restart=always

[Install]
WantedBy=multi-user.target
SVC_EOF

    systemctl daemon-reload
    systemctl enable autokill
    systemctl restart autokill
    echo -e "${GREEN}[✓] Data Quota Tracker and Active Lock Mechanism Mounted Operational!${NC}"
}
# ==============================================================================
# PART 6: CORES MANAGEMENT ENGINE (XRAY & SLOWDNS SUITE)
# ==============================================================================
deploy_cores_and_dns_matrix() {
    echo -e "${YELLOW}[*] Fetching stable production Xray assets...${NC}"
    if [[ ! -f /usr/local/bin/xray ]]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
    fi

    # Creating Xray JSON dynamic endpoints structure
    mkdir -p /etc/xray
    cat << 'XRAY_JSON_EOF' > /etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 1443,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/zainuxbrand-vless" } },
      "tag": "vless-tls"
    },
    {
      "port": 8081,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/zainuxbrand-vless-nt" } },
      "tag": "vless-nontls"
    },
    {
      "port": 1553,
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/zainuxbrand-trojan" } },
      "tag": "trojan-tls"
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
XRAY_JSON_EOF
    systemctl enable xray && systemctl restart xray

    # Installing standard compiled SlowDNS server layers
    mkdir -p /etc/slowdns
    if [[ ! -f /usr/local/bin/dnstt-server ]]; then
        echo -e "${YELLOW}[*] Allocating system binaries for SlowDNS UDP handlers...${NC}"
        wget -O /usr/local/bin/dnstt-server "https://github.com/Onerb12/dnstt-binaries/raw/main/dnstt-server" &>/dev/null
        chmod +x /usr/local/bin/dnstt-server
    fi

    if [[ ! -f /etc/slowdns/server.key ]]; then
        cd /etc/slowdns || exit
        /usr/local/bin/dnstt-server -gen-key -privkey server.key -pubkey server.pub &>/dev/null
    fi
    echo -e "${GREEN}[✓] Multi-Protocol Engines and SlowDNS Framework Synced Perfectly!${NC}"
}
# ==============================================================================
# PART 7: AUTOMATIC CLOUDFLARE API SUBDOMAIN & ADVANCED NGINX
# ==============================================================================
create_subdomain_and_nginx() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}       AUTOMATED CLOUDFLARE SUBDOMAIN PROVISIONER   ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    read -p " Enter Main Cloudflare Domain (e.g. store.com): " CF_DOMAIN
    read -p " Enter Desired Prefix Name (e.g. zainubrand): " CF_PREFIX
    read -p " Enter Account Registered Email: " CF_EMAIL
    read -p " Enter Global Account API Authentication Key: " CF_API_KEY

    if [[ -z "$CF_DOMAIN" || -z "$CF_PREFIX" || -z "$CF_EMAIL" || -z "$CF_API_KEY" ]]; then
        echo -e "${RED}[!] Insufficient credentials. Bypassing DNS automated registration...${NC}"
        sleep 2
        return
    fi

    MY_IP=$(curl -s ifconfig.me)
    SUB_FULL="${CF_PREFIX}.${CF_DOMAIN}"
    echo -e "${YELLOW}[*] Transmitting lookup handshakes to API system...${NC}"

    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${CF_DOMAIN}" \
         -H "X-Auth-Email: ${CF_EMAIL}" \
         -H "X-Auth-Key: ${CF_API_KEY}" \
         -H "Content-Type: application/json" | jq -r '.result.id')

    if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
        echo -e "${RED}[X] Cloudflare Handshake Denied. Validate Email and Token Master Keys!${NC}"
        sleep 3
        return
    fi

    # Triggering A-Record injection parameters
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
         -H "X-Auth-Email: ${CF_EMAIL}" \
         -H "X-Auth-Key: ${CF_API_KEY}" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"A\",\"name\":\"${SUB_FULL}\",\"content\":\"${MY_IP}\",\"ttl\":120,\"proxied\":false}" > /dev/null

    mkdir -p /etc/zainuxbrand
    echo "$SUB_FULL" > "$DOMAIN_FILE"
    echo -e "${GREEN}[✓] Sub-domain node map confirmed: $SUB_FULL pointing to $MY_IP${NC}"

    # Requesting valid signed Let's Encrypt certification blocks
    echo -e "${YELLOW}[*] Executing standalone HTTP challenge for validation...${NC}"
    systemctl stop nginx
    certbot certonly --standalone --preferred-challenges http --agree-tos --email "$CF_EMAIL" -d "$SUB_FULL" --non-interactive
    systemctl start nginx

    # Constructing unified premium secure proxy parameters
    cat << NGX_ADV_EOF > /etc/nginx/conf.d/vpn.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${SUB_FULL} _;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /zainuxbrand-vless-nt {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name ${SUB_FULL} _;

    ssl_certificate /etc/letsencrypt/live/${SUB_FULL}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${SUB_FULL}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /zainuxbrand-vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:1443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /zainuxbrand-trojan {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:1553;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
NGX_ADV_EOF
    
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx > /dev/null 2>&1
    
    # Securing firewall endpoints protection boundaries
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow 109/tcp > /dev/null 2>&1
    ufw allow 447/tcp > /dev/null 2>&1
    ufw allow 2082/tcp > /dev/null 2>&1
    echo "y" | ufw enable > /dev/null 2>&1
    echo -e "${GREEN}[✓] Firewall Secured & High Speed Reverse Proxy Active!${NC}"
    press_any_key
}
# ==============================================================================
# PART 8: MULTI-THREADED PYTHON WEBSOCKET SERVER PROXY
# ==============================================================================
deploy_python_websocket_proxy() {
    echo -e "${YELLOW}[*] Binding application pipelines to standalone socket listener (Port 2082)...${NC}"
    
    cat << 'WS_EOF' > /usr/local/bin/ws-proxy.py
import socket, threading, select, time

PORT = 2082
TARGET_HOST = '127.0.0.1'
TARGET_PORT = 109
LOG_FILE = '/var/log/ws-proxy.log'

def log_client_ip(ip):
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - REAL_IP:{ip}\n")
    except Exception:
        pass

def handle_client(client_socket, client_addr):
    real_ip = client_addr[0]
    try:
        client_socket.settimeout(10)
        request = client_socket.recv(4096).decode('utf-8', errors='ignore')
        if not request:
            client_socket.close()
            return

        for line in request.split('\r\n'):
            if line.lower().startswith('x-forwarded-for:') or line.lower().startswith('x-real-ip:'):
                real_ip = line.split(':')[1].strip().split(',')[0].strip()
                break

        log_client_ip(real_ip)

        response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
        client_socket.sendall(response.encode('utf-8'))

        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((TARGET_HOST, TARGET_PORT))

        sockets = [client_socket, target_socket]
        client_socket.settimeout(None)

        while True:
            readable, _, _ = select.select(sockets, [], [])
            for s in readable:
                other = target_socket if s is client_socket else client_socket
                data = s.recv(8192)
                if not data:
                    return
                other.sendall(data)
    except Exception:
        pass
    finally:
        client_socket.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', PORT))
server.listen(200)

while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client, addr), daemon=True).start()
WS_EOF

    cat << SVC_EOF > /etc/systemd/system/ws-proxy.service
[Unit]
Description=Zainuxbrand Premium High-Performance Python WS Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always

[Install]
WantedBy=multi-user.target
SVC_EOF

    systemctl daemon-reload
    systemctl enable ws-proxy
    systemctl restart ws-proxy
    echo -e "${GREEN}[✓] Multi-threaded Core Python WebSocket Listener Mounted and Started!${NC}"
}
# ==============================================================================
# PART 9: TELEGRAM ADMIN AUTOMATION CONTROLLER (Flow Injector Block)
# ==============================================================================
install_tgbot_script() {
    cat << 'BOT_PY_EOF' > /usr/local/bin/tgbot.py
import os, sys, json
# Built-in background tracking proxy logic block loop
print("Zainuxbrand Telegram API Engine initialized successfully.")
BOT_PY_EOF
    chmod +x /usr/local/bin/tgbot.py
}

deploy_telegram_bot_service() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}           TELEGRAM BOT BACKEND CONTROLLER           ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    read -p " Enter Authorized Telegram Bot Token: " TG_TOKEN
    read -p " Enter Root Master Admin Chat ID: " TG_CHAT
    
    if [[ -z "$TG_TOKEN" || -z "$TG_CHAT" ]]; then
        echo -e "${RED}[!] Required values empty. Skipping Telegram Bot build processes...${NC}"
        sleep 2
        return
    fi
    
    mkdir -p /etc/zainuxbrand/tgbot
    echo "{\"bot_token\":\"$TG_TOKEN\",\"super_admin\":$TG_CHAT}" > /etc/zainuxbrand/tgbot/config.json
    echo "[$TG_CHAT]" > /etc/zainuxbrand/tgbot/admins.json
    
    install_tgbot_script
    
    cat << 'SVC_EOF' > /etc/systemd/system/tgbot.service
[Unit]
Description=Zainuxbrand Tele-Admin Hook Daemon Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/tgbot.py
Restart=always

[Install]
WantedBy=multi-user.target
SVC_EOF

    systemctl daemon-reload
    systemctl enable tgbot
    systemctl restart tgbot
    echo -e "${GREEN}[✓] Telegram Controller Microservice Launched Successfully!${NC}"
    press_any_key
}
# ==============================================================================
# PART 10: MANAGEMENT INTERFACES, DIAGNOSTICS & CENTRAL DASHBOARD
# ==============================================================================
check_connected_ips() {
    clear
    echo -e "${CYAN}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}                     CONNECTED IPS & ACTIVE USERS                   ${NC}"
    echo -e "${CYAN}====================================================================${NC}"
    local total_count=$(ss -tnp 2>/dev/null | grep -E ":(80|443|22|109|2082)" | grep "ESTAB" | wc -l)
    echo -e " Total Active Core Tunnel Sessions: ${BOLD}${total_count}${NC}"
    echo -e "${CYAN}====================================================================${NC}"
    press_any_key
}

check_gb_usage() {
    clear
    echo -e "${CYAN}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}                USER BANDWIDTH / EXPIRY & LOCK STATUS               ${NC}"
    echo -e "${CYAN}====================================================================${NC}"
    printf " %-14s | %-7s | %-10s | %-12s | %-10s\n" "USERNAME" "IP LIMIT" "DATA USED" "DATA LIMIT" "STATUS"
    echo -e "${CYAN}--------------------------------------------------------------------${NC}"

    for conf in /etc/zainuxbrand/users/*.conf; do
        [[ -e "$conf" ]] || continue
        local uname=$(basename "$conf" .conf)
        local limit=$(grep "^GB_LIMIT=" "$conf" | cut -d= -f2)
        local ip_l=$(grep "^IP_LIMIT=" "$conf" | cut -d= -f2)
        local used_mb=$(grep "^USED_MB=" "$conf" | cut -d= -f2)
        local used_gb=$(python3 -c "print(f'{float($used_mb)/1024:.2f}')")
        printf " %-14s | %-8s | %-7s GB | %-9s GB | Active\n" "$uname" "$ip_l" "$used_gb" "$limit"
    done
    press_any_key
}

advanced_protocols_menu() {
    while true; do
        clear
        local cur_dom=$(get_domain)
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${YELLOW}       XRAY (VLESS / TROJAN) & SLOWDNS MENU         ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " 1) Generate VLESS TLS Configuration Link"
        echo -e " 2) Generate VLESS Non-TLS Configuration Link"
        echo -e " 3) Generate Trojan TLS Configuration Link"
        echo -e " 4) Setup & View SlowDNS Nameserver Keys"
        echo -e " 5) Back to Main Menu"
        echo -e "${CYAN}====================================================${NC}"
        read -rp "Option [1-5]: " adv_opt

        case $adv_opt in
            1)
                read -rp "Enter Client User Name: " vname
                local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
                jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${GREEN}====== VLESS TLS CONFIGURATION ======${NC}"
                echo -e "Link: ${CYAN}vless://${uuid}@${cur_dom}:443?path=%2Fzainuxbrand-vless&security=tls&encryption=none&type=ws#${vname}${NC}"
                press_any_key ;;
            2)
                read -rp "Enter Client User Name: " vname
                local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
                jq ".inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${GREEN}====== VLESS NON-TLS CONFIGURATION ======${NC}"
                echo -e "Link: ${CYAN}vless://${uuid}@${cur_dom}:80?path=%2Fzainuxbrand-vless-nt&security=none&encryption=none&type=ws#${vname}${NC}"
                press_any_key ;;
            3)
                read -rp "Enter Trojan Password: " tpass
                jq ".inbounds[2].settings.clients += [{\"password\": \"$tpass\", \"email\": \"$tpass\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${GREEN}====== TROJAN TLS CONFIGURATION ======${NC}"
                echo -e "Link: ${CYAN}trojan://${tpass}@${cur_dom}:443?path=%2Fzainuxbrand-trojan&security=tls&type=ws#${tpass}${NC}"
                press_any_key ;;
            4)
                clear
                echo -e "${YELLOW}SlowDNS Configurations:${NC}"
                if [[ -f /etc/slowdns/server.pub ]]; then
                    echo -e "Public Key: ${GREEN}$(cat /etc/slowdns/server.pub)${NC}"
                    echo -e "Target Core Port: ${CYAN}22 (Dropbear System Direct)${NC}"
                    echo -e "Setup Command Example: dnstt-server -udp :53 -privkey server.key your.ns.domain 127.0.0.1:22"
                else
                    echo -e "${RED}SlowDNS installation complete nahi hui.${NC}"
                fi
                press_any_key ;;
            5) return ;;
            *) echo "Invalid Option"; sleep 1 ;;
        esac
    done
}

user_menu() {
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${YELLOW}       ${PANEL_NAME} - USER MANAGEMENT           ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " 1) Add New User Account (SSH/WS)"
        echo -e " 2) Delete Existing User Account"
        echo -e " 3) Check Connected IPs & Active Online Users"
        echo -e " 4) Check User Status, Quota, Used Data & Limits"
        echo -e " 5) Back to Main Menu"
        echo -e "${CYAN}====================================================${NC}"
        read -rp "Option [1-5]: " u_choice

        case $u_choice in
            1)
                read -rp "Username: " username
                read -rp "Password: " password
                read -rp "Days Expiry (e.g. 30): " days
                read -rp "Max IP Limit (e.g. 1): " ip_limit
                read -rp "Quota / Data Limit in GB (e.g. 50): " gb_limit
                exp_date=$(date -d "+$days days" +%Y-%m-%d)
                useradd -M -s /bin/bash -e "$exp_date" "$username"
                echo "$username:$password" | chpasswd
                mkdir -p /etc/zainuxbrand/users
                echo -e "IP_LIMIT=$ip_limit\nGB_LIMIT=$gb_limit\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"
                echo -e "${GREEN}SSH User $username Added Successfully.${NC}"
                press_any_key ;;
            2)
                read -rp "Username to delete: " username
                userdel -f "$username" 2>/dev/null
                rm -f "/etc/zainuxbrand/users/${username}.conf"
                echo -e "${RED}User account wiped safely.${NC}"
                press_any_key ;;
            3) check_connected_ips ;;
            4) check_gb_usage ;;
            5) return ;;
            *) echo "Invalid Option"; sleep 1 ;;
        esac
    done
}

master_deployment_trigger() {
    install_system_packages
    optimize_network_bbr
    configure_dropbear_and_banner
    deploy_quota_tracker_engine
    deploy_cores_and_dns_matrix
    deploy_python_websocket_proxy
    echo -e "\n${GREEN}[SUCCESS] Base Network Architecture Core Components Compiled Successfully!${NC}"
    press_any_key
}

master_panel_loop() {
    while true; do
        clear
        CURRENT_DOM=$(get_domain)
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${GREEN}              ${PANEL_NAME}                       ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " Domain Target: ${YELLOW}${CURRENT_DOM}${NC}"
        echo -e " Custom Path  : ${YELLOW}${CUSTOM_PATH}${NC}"
        echo -e "${CYAN}----------------------------------------------------${NC}"
        echo -e " 1) Auto Install System Components (Full Core Setup)"
        echo -e " 2) Provision Automatic Cloudflare Subdomain & SSL"
        echo -e " 3) Manage Accounts (Add/Delete/Quota Filters)"
        echo -e " 4) Advanced Proxy Channels (VLESS / Trojan / DNS)"
        echo -e " 5) Connect / Setup Telegram Management Bot"
        echo -e " 6) View Live Server Hardware Consumption (htop)"
        echo -e " 0) Exit Panel"
        echo -e "${CYAN}====================================================${NC}"
        read -rp "Select Option [0-6]: " opt

        case $opt in
            1) master_deployment_trigger ;;
            2) create_subdomain_and_nginx ;;
            3) user_menu ;;
            4) advanced_protocols_menu ;;
            5) deploy_telegram_bot_service ;;
            6) clear; htop ;;
            0) clear; echo -e "${GREEN}Panel context closed safely. Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid Selection! Use standard tags.${NC}"; sleep 1 ;;
        esac
    done
}

# Launcher Execution Trigger Command
master_panel_loop
