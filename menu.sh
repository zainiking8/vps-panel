#!/bin/bash

# ==============================================================================
# Script Name   : ZAINUXBRAND VIP Premium Matrix Pro Engine
# Custom Path   : /zainuxbrand
# Interface     : Cyberpunk Hyper-Neon Style (Custom Redesign)
# ==============================================================================

NC='\033[0m'
BOLD='\033[1m'
BLINK='\033[5m'

R_NEON='\033[38;5;196m'   # Electric Red
G_NEON='\033[38;5;46m'    # Matrix Green
Y_NEON='\033[38;5;226m'   # Cyber Gold
B_NEON='\033[38;5;27m'    # Deep Tech Blue
M_NEON='\033[38;5;201m'   # Hyper Neon Pink
C_NEON='\033[38;5;51m'    # Ice Cyan
W_NEON='\033[38;5;231m'   # Pure Stark White
G_DARK='\033[38;5;244m'   # Dark Steel Grey

PANEL_NAME="⚡ Z A I N U X B R A N D   V I P   P R O ⚡"
BANNER_FILE="/etc/issue.net"
CUSTOM_PATH="/zainuxbrand"
DOMAIN_FILE="/etc/zainuxbrand/domain.conf"
XRAY_CONFIG="/etc/xray/config.json"
SLOWDNS_DIR="/etc/slowdns"

if [[ $EUID -ne 0 ]]; then
   echo -e "${R_NEON}┌────────────────────────────────────────────────────────┐${NC}"
   echo -e "${R_NEON}│ [CRITICAL ERROR] Run this engine with root privileges! │${NC}"
   echo -e "${R_NEON}└────────────────────────────────────────────────────────┘${NC}"
   exit 1
fi

get_domain() {
    if [[ -f "$DOMAIN_FILE" ]]; then
        cat "$DOMAIN_FILE" | tr -d '\r\n'
    else
        echo "No Domain Configured"
    fi
}

press_any_key() {
    echo -e "\n${M_NEON}  ⚡ [System] Press [ENTER] to return to cyber grid...${NC}"
    read -r
}
fix_dropbear_core() {
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

    cat << 'DB_CONF' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=22
DROPBEAR_EXTRA_ARGS="-p 109 -p 447 -b /etc/issue.net"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
DB_CONF

    systemctl daemon-reload
    systemctl enable dropbear
    systemctl restart dropbear
}
install_python_tracker() {
    cat << 'PY_EOF' > /usr/local/bin/autokill.py
import os
import sys
import time
import subprocess
import re

USER_DIR = "/etc/zainuxbrand/users"

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
PY_EOF
    cat << 'PY_LOOP_EOF' >> /usr/local/bin/autokill.py
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
PY_LOOP_EOF

    chmod +x /usr/local/bin/autokill.py
    cat << 'SVC_EOF' > /etc/systemd/system/autokill.service
[Unit]
Description=Zainuxbrand Auto-Kill & Bandwidth Tracking Service
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
}

install_tgbot_script() {
    cat << 'PY_BOT_EOF' > /usr/local/bin/tgbot.py
import os
import subprocess

DOMAIN_FILE = "/etc/zainuxbrand/domain.conf"
NGINX_TEMPLATE = """server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name {dom} _;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
"""
def get_domain():
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE) as f:
            return f.read().strip()
    return "No Domain Set"

def apply_nginx_config():
    dom = get_domain()
    if dom == "No Domain Set":
        return
    os.makedirs("/etc/nginx/conf.d", exist_ok=True)
    with open("/etc/nginx/conf.d/vpn.conf", "w") as f:
        f.write(NGINX_TEMPLATE.replace("{dom}", dom))
    subprocess.run(["rm", "-f", "/etc/nginx/sites-enabled/default"])
    subprocess.run(["systemctl", "restart", "nginx"])
PY_BOT_EOF
}
setup_xray_and_slowdns_cores() {
    if [[ ! -f /usr/local/bin/xray ]]; then
        echo -e "  ${C_NEON}➔ Injecting high-performance Xray-Core binary...${NC}"
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    fi

    mkdir -p /etc/xray
    mkdir -p /usr/local/etc/xray
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

    ln -sf /etc/xray/config.json /usr/local/etc/xray/config.json
    systemctl daemon-reload
    systemctl enable xray && systemctl restart xray

    mkdir -p /etc/slowdns
    if [[ ! -f /usr/local/bin/dnstt-server ]]; then
        echo -e "  ${C_NEON}➔ Locking cryptographic SlowDNS core engine...${NC}"
        wget -O /usr/local/bin/dnstt-server "https://github.com/Onerb12/dnstt-binaries/raw/main/dnstt-server" &>/dev/null
        chmod +x /usr/local/bin/dnstt-server
    fi

    if [[ ! -f /etc/slowdns/server.key ]]; then
        cd /etc/slowdns || exit
        /usr/local/bin/dnstt-server -gen-key -privkey server.key -pubkey server.pub &>/dev/null
    fi
}
apply_advanced_nginx() {
    local MY_DOMAIN=$(get_domain)
    if [[ "$MY_DOMAIN" == "No Domain Set" || -z "$MY_DOMAIN" ]]; then return; fi

    cat << NGX_ADV_EOF > /etc/nginx/conf.d/vpn.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${MY_DOMAIN} _;

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
    server_name ${MY_DOMAIN} _;

    ssl_certificate /etc/letsencrypt/live/${MY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${MY_DOMAIN}/privkey.pem;
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
    systemctl restart nginx 2>/dev/null
}

apply_nginx_config() {
    apply_advanced_nginx
}

add_domain_option() {
    clear
    echo -e "${M_NEON}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${M_NEON}│ ${BOLD}${Y_NEON}         🌐 DOMAIN CONFIGURATION MATRIX                ${M_NEON}│${NC}"
    echo -e "${M_NEON}└────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    read -rp "  ➔ Enter Subdomain Node (e.g. zaine.uvlist.filegear-sg.me): " new_dom

    if [[ -z "$new_dom" ]]; then
        echo -e "  ${R_NEON}[!] Blank configurations are rejected by core system.${NC}"
    else
        mkdir -p /etc/zainuxbrand
        echo "$new_dom" > "$DOMAIN_FILE"
        echo -e "\n  ${G_NEON}[✔] Domain linked to infrastructure: ${C_NEON}${new_dom}${NC}"
        apply_nginx_config
    fi
    press_any_key
}
install_all_components() {
    clear
    echo -e "${C_NEON}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${C_NEON}│ ${BOLD}${W_NEON}     🚀 SYSTEM ARCHITECTURE FLUID INSTALLATION        ${C_NEON}│${NC}"
    echo -e "${C_NEON}└────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    echo -e "  ${M_NEON}➔${NC} Syncing standard mirror repositories..."
    apt update -y && apt upgrade -y &>/dev/null

    echo -e "  ${M_NEON}➔${NC} Compiling binary dependencies..."
    apt install -y curl wget unzip tar net-tools socat jq openssl nginx dropbear certbot python3 python3-pip lsof iptables git build-essential uuid-runtime &>/dev/null

    echo -e "  ${M_NEON}➔${NC} Binding real-time secure network banner..."
    cat << 'BANNER_EOF' > $BANNER_FILE
==================================================
WELCOME TO ZAINUXBRAND VIP VPN
NUMBER: 03077716993
TELEGRAM: https://t.me/zainuxbrand
- NO TORRENT / NO MULTILOGIN
==================================================
BANNER_EOF

    fix_dropbear_core
    sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
    systemctl restart ssh

    echo -e "  ${M_NEON}➔${NC} Triggering background tunnel layers..."
    setup_xray_and_slowdns_cores

    cat << 'WS_EOF' > /usr/local/bin/ws-proxy.py
import socket, threading, select, time

PORT = 2082
TARGET_HOST = '127.0.0.1'
TARGET_PORT = 109
LOG_FILE = '/var/log/ws-proxy.log'

def log_client_ip(ip):
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - IP:{ip}\n")
    except Exception:
        pass

def handle_client(client_socket, client_addr):
    real_ip = client_addr
    try:
        client_socket.settimeout(10)
        request = client_socket.recv(4096).decode('utf-8', errors='ignore')
        if not request:
            client_socket.close()
            return

        for line in request.split('\r\n'):
            if line.lower().startswith('x-forwarded-for:') or line.lower().startswith('x-real-ip:'):
                real_ip = line.split(':').strip().split(',').strip()
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
Description=Zainuxbrand WebSocket Proxy Service
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
    apply_nginx_config

    echo -e "  ${M_NEON}➔${NC} Booting quantitative trackers..."
    install_python_tracker

    echo -e "\n  ${G_NEON}[✔] Cyber stack deployed perfectly! All modules online.${NC}"
    press_any_key
}

setup_ssl() {
    clear
    local current_dom=$(get_domain)

    if [[ "$current_dom" == "No Domain Configured" || -z "$current_dom" ]]; then
        echo -e "  ${R_NEON}[!] Map domain address via option first!${NC}"
        press_any_key
        return
    fi

    echo -e "${C_NEON}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${C_NEON}│ ${BOLD}${Y_NEON}        🔒 PROVISIONING SECURE SSL ENCRYPTION           ${C_NEON}│${NC}"
    echo -e "${C_NEON}└────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    systemctl stop nginx
    certbot certonly --standalone --preferred-challenges http --agree-tos --register-unsafely-without-email -d "$current_dom"

    if [[ -f "/etc/letsencrypt/live/$current_dom/fullchain.pem" ]]; then
        echo -e "\n  ${G_NEON}[✔] SSL active! Secure channels verified.${NC}"
        apply_nginx_config
    else
        echo -e "  ${R_NEON}[!] Verification timeout. Check Cloudflare record settings.${NC}"
    fi
    press_any_key
}
check_connected_ips() {
    clear
    echo -e "${M_NEON}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${M_NEON}│ ${BOLD}${C_NEON}          REALTIME RECURSIVE METRICS SHIELD             ${M_NEON}│${NC}"
    echo -e "${M_NEON}└────────────────────────────────────────────────────────┘${NC}"
    local total_count=$(ss -tnp 2>/dev/null | grep -E ":(80|443|22|109)" | grep "ESTAB" | wc -l)
    echo -e "\n  ⚡ Live structural network sessions: ${BOLD}${G_NEON}${total_count}${NC}"
    echo -e "${G_DARK}  ────────────────────────────────────────────────────────${NC}"
    press_any_key
}

check_gb_usage() {
    clear
    echo -e "${M_NEON}🚀 [Bandwidth Log Grid Overview]${NC}"
    echo -e "${G_DARK}─"
    printf "  %-14s | %-7s | %-10s | %-12s | %-10s\n" "IDENTITY" "IP MAX" "USED DATA" "LIMIT QUOTA" "INTEGRITY"
    echo -e "${G_DARK}─"

    if [ -d /etc/zainuxbrand/users ]; then
        for conf in /etc/zainuxbrand/users/*.conf; do
            [[ -e "$conf" ]] || continue
            local uname=$(basename "$conf" .conf)
            local limit=$(grep "^GB_LIMIT=" "$conf" | cut -d= -f2)
            local ip_l=$(grep "^IP_LIMIT=" "$conf" | cut -d= -f2)
            local used_mb=$(grep "^USED_MB=" "$conf" | cut -d= -f2)
            local used_gb=$(python3 -c "print(f'{float($used_mb)/1024:.2f}')")
            printf "  %-14s | %-7s | %-7s GB | %-9s GB | Valid\n" "$uname" "$ip_l" "$used_gb" "$limit"
        done
    fi
    press_any_key
}

advanced_protocols_menu() {
    while true; do
        clear
        local cur_dom=$(get_domain)
        echo -e "${M_NEON}⚡ ─── [ XRAY CORE CORE PROTOCOLS SUITE ] ─── ⚡${NC}"
        echo -e "  1) Extract Branded VLESS Websocket (TLS Port 443)"
        echo -e "  2) Extract Branded VLESS Websocket (Non-TLS Port 80)"
        echo -e "  3) Extract Branded Trojan Secure (TLS Port 443)"
        echo -e "  4) Dump Crypto Public SlowDNS Server Keys"
        echo -e "  5) Return to main matrix panel grid"
        echo -e "${G_DARK}────────────────────────────────────────────────────────${NC}"
        read -rp "  Selection index [1-5]: " adv_opt

        case $adv_opt in
            1)
                read -rp "  Enter account user marker tag: " vname
                local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
                jq ".inbounds.settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${G_NEON}==================================================${NC}"
                echo -e "${BOLD}${W_NEON}WELCOME TO ZAINUXBRAND VIP VPN${NC}"
                echo -e "${BOLD}${Y_NEON}NUMBER: 03077716993${NC}"
                echo -e "${BOLD}${C_NEON}TELEGRAM: https://t.me/zainuxbrand${NC}"
                echo -e "${G_NEON}==================================================${NC}"
                echo -e "  Link    : ${C_NEON}vless://${uuid}@${cur_dom}:443?path=%2Fzainuxbrand-vless&security=tls&encryption=none&type=ws#${vname}${NC}"
                press_any_key
                ;;
            2)
                read -rp "  Enter account user marker tag: " vname
                local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
                jq ".inbounds.settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${G_NEON}==================================================${NC}"
                echo -e "${BOLD}${W_NEON}WELCOME TO ZAINUXBRAND VIP VPN${NC}"
                echo -e "${BOLD}${Y_NEON}NUMBER: 03077716993${NC}"
                echo -e "${BOLD}${C_NEON}TELEGRAM: https://t.me/zainuxbrand${NC}"
                echo -e "${G_NEON}==================================================${NC}"
                echo -e "  Link    : ${C_NEON}vless://${uuid}@${cur_dom}:80?path=%2Fzainuxbrand-vless-nt&security=none&encryption=none&type=ws#${vname}${NC}"
                press_any_key
                ;;
            3)
                read -rp "  Set secure trojan password token: " tpass
                jq ".inbounds.settings.clients += [{\"password\": \"$tpass\", \"email\": \"$tpass\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${G_NEON}==================================================${NC}"
                echo -e "${BOLD}${W_NEON}WELCOME TO ZAINUXBRAND VIP VPN${NC}"
                echo -e "${BOLD}${Y_NEON}NUMBER: 03077716993${NC}"
                echo -e "${BOLD}${C_NEON}TELEGRAM: https://t.me/zainuxbrand${NC}"
                echo -e "${G_NEON}==================================================${NC}"
                echo -e "  Link    : ${C_NEON}trojan://${tpass}@${cur_dom}:443?path=%2Fzainuxbrand-trojan&security=tls&type=ws#${tpass}${NC}"
                press_any_key
                ;;
            4)
                clear
                echo -e "${Y_NEON}==================================================${NC}"
                echo -e "${BOLD}${W_NEON}WELCOME TO ZAINUXBRAND VIP VPN${NC}"
                echo -e "${BOLD}${Y_NEON}NUMBER: 03077716993${NC}"
                echo -e "${BOLD}${C_NEON}TELEGRAM: https://t.me/zainuxbrand${NC}"
                echo -e "${Y_NEON}==================================================${NC}"
                if [[ -f /etc/slowdns/server.pub ]]; then
                    echo -e "  ➔ Node Public Key: ${G_NEON}$(cat /etc/slowdns/server.pub)${NC}"
                    echo -e "  ➔ Target Channel : Port 22 (Dropbear Execution)"
                else
                    echo -e "  ${R_NEON}[!] Server files unbuilt. Fire option 1 first.${NC}"
                fi
                press_any_key
                ;;
            5) return ;;
        esac
    done
}

user_menu() {
    while true; do
        clear
        echo -e "${C_NEON}⚡ ─── [ ACCOUNT ACCELERATION PROVISIONING ENGINE ] ─── ⚡${NC}"
        echo -e "  1) Provision Fresh Multi-Protocol Account"
        echo -e "  2) Purge / Annihilate Target User Credentials"
        echo -e "  3) Inspect Active Real-Time IP Allocations"
        echo -e "  4) Dump Quota Records Data Metrics"
        echo -e "  5) Safe-return to dashboard matrix root"
        echo -e "${G_DARK}────────────────────────────────────────────────────────${NC}"
        read -rp "  Selection index [1-5]: " u_choice

        case $u_choice in
            1)
                read -rp "  Set Account User ID Name: " username
                read -rp "  Set Client Access Password: " password
                read -rp "  Set Duration Allocation (Days): " days
                read -rp "  Set Max Simultaneous IP Bound: " ip_limit
                read -rp "  Set Bandwidth Volumetric Quota (GB): " gb_limit
                exp_date=$(date -d "+$days days" +%Y-%m-%d)
                useradd -M -s /bin/bash -e "$exp_date" "$username"
                echo "$username:$password" | chpasswd
                mkdir -p /etc/zainuxbrand/users
                echo -e "IP_LIMIT=$ip_limit\nGB_LIMIT=$gb_limit\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"
                echo -e "  ${G_NEON}[✔] Profile linked under secure database framework.${NC}"
                press_any_key
                ;;
            2)
                read -rp "  Identify username token to purge: " username
                userdel -f "$username" 2>/dev/null
                rm -f "/etc/zainuxbrand/users/${username}.conf"
                echo -e "  ${Y_NEON}[!] Structural database records wiped cleanly.${NC}"
                press_any_key
                ;;
            3) check_connected_ips ;;
            4) check_gb_usage ;;
            5) return ;;
        esac
    done
}

status_check() {
    clear
    echo -e "  ${Y_NEON}[System Port Vector Diagnostics]${NC}\n"
    netstat -tulpn | grep -E "nginx|xray|dropbear|python"
    press_any_key
}

uninstall_panel() {
    clear
    echo -e "  ${R_NEON}➔ Flushing deep core matrix profiles from virtual machine...${NC}"
    systemctl stop ws-proxy autokill xray nginx dropbear 2>/dev/null
    systemctl disable ws-proxy autokill xray 2>/dev/null
    rm -f /etc/systemd/system/ws-proxy.service /etc/systemd/system/autokill.service 2>/dev/null
    rm -rf /etc/zainuxbrand /usr/local/bin/ws-proxy.py /usr/local/bin/autokill.py /etc/nginx/conf.d/vpn.conf /etc/xray/config.json /usr/local/bin/menu 2>/dev/null
    systemctl daemon-reload
    systemctl restart nginx 2>/dev/null
    echo -e "\n  ${G_NEON}[✔] Total framework wipe complete. Purged cleanly!${NC}"
    exit 0
}

while true; do
    clear
    CURRENT_DOM=$(get_domain)
    echo -e "${C_NEON}┏────────────────────────────────────────────────────────┓${NC}"
    echo -e "${C_NEON}│${BOLD}${Y_NEON}        ${PANEL_NAME}        ${C_NEON}│${NC}"
    echo -e "${C_NEON}┗────────────────────────────────────────────────────────┛${NC}"
    echo -e "  ${G_DARK}⚡ [Target Domain Node] :${NC} ${G_NEON}${CURRENT_DOM}${NC}"
    echo -e "  ${G_DARK}⚡ [Virtual File Path] :${NC} ${W_NEON}${CUSTOM_PATH}${NC}"
    echo -e "${G_DARK}─────────────────────────────────────────────────────────${NC}"
    echo -e "  1) Automated Setup / Full System Reinstallation"
    echo -e "  2) Assign / Remap Network Subdomain Address"
    echo -e "  3) Trigger Let's Encrypt SSL Security Protocols"
    echo -e "  4) Client Accounts Management Central Node"
    echo -e "  5) System Live Port Metric Vector Monitors"
    echo -e "  6) Advanced Core Protocols Suite (VLESS/Trojan/SlowDNS)"
    echo -e "  7) Complete Pure Structural Wipe (Uninstall Core System)"
    echo -e "  8) Close Operations Interface"
    echo -e "${C_NEON}─────────────────────────────────────────────────────────${NC}"
    read -rp "  Select vector sequence execution index [01-08]: " opt

    case $opt in
        1|01) install_all_components ;;
        2|02) add_domain_option ;;
        3|03) setup_ssl ;;
        4|04) user_menu ;;
        5|05) status_check ;;
        6|06) advanced_protocols_menu ;;
        7|07) uninstall_panel ;;
        8|08) exit 0 ;;
        *) echo " Execution error: Invalid indexing token."; sleep 1 ;;
    esac
done
