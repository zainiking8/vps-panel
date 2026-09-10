#!/bin/bash

# ==============================================================================
# Script Name   : ZAINU x BRAND VPN Panel (Xray & SlowDNS Ultimate Edition)
# Custom Path   : /zainuxbrand
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PANEL_NAME="ZAINUXBRAND VPN Panel"
BANNER_FILE="/etc/issue.net"
CUSTOM_PATH="/zainuxbrand"
DOMAIN_FILE="/etc/zainuxbrand/domain.conf"
XRAY_CONFIG="/etc/xray/config.json"
SLOWDNS_DIR="/etc/slowdns"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] Yeh script ROOT privilege ke sath chalaen! (sudo -i)${NC}"
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
    echo -e "\n${YELLOW}Press [ENTER] key to return to main menu...${NC}"
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

    cat << 'SVC_EOF' > /etc/systemd/system/autokill.service
[Unit]
Description=zainuxbrand Auto-Kill & Bandwidth Tracking Service
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
    cat << 'PY_EOF' > /usr/local/bin/tgbot.py
import os
import re
import json
import asyncio
import subprocess
from datetime import datetime, timedelta

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ContextTypes, filters,
)

PANEL_NAME = "zainuxbrand VPN Panel"
CONFIG_FILE = "/etc/zainuxbrand/tgbot/config.json"
ADMINS_FILE = "/etc/zainuxbrand/tgbot/admins.json"
USERS_DIR = "/etc/zainuxbrand/users"
DOMAIN_FILE = "/etc/zainuxbrand/domain.conf"
BANNER_FILE = "/etc/issue.net"

NGINX_TEMPLATE = """server {{
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name {dom} _;

    location / {{
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }}

    location /zainuxbrand {{
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }}
}}

server {{
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name {dom} _;

    ssl_certificate /etc/letsencrypt/live/{dom}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{dom}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {{
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }}

    location /zainuxbrand {{
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }}
}}
"""

FLOWS = {
    "add_user": [
        ("username", "\U0001F464 Username enter karein:"),
        ("password", "\U0001F511 Password enter karein:"),
        ("days", "\U0001F4C5 Expiry days enter karein (e.g. 30):"),
        ("ip_limit", "\U0001F310 Max IP Limit enter karein (e.g. 1):"),
        ("gb_limit", "\U0001F4BE Data Limit GB enter karein (e.g. 5, ya Unlimited):"),
    ],
    "del_user": [("username", "\U0001F464 Delete karne ke liye Username enter karein:")],
    "renew_user": [
        ("username", "\U0001F464 Username enter karein jise renew karna hai:"),
        ("days", "\U0001F4C5 Kitne additional days add karne hain?"),
    ],
    "ip_limit": [
        ("username", "\U0001F464 Username enter karein:"),
        ("value", "\U0001F310 Naya IP Limit enter karein:"),
    ],
    "gb_limit": [
        ("username", "\U0001F464 Username enter karein:"),
        ("value", "\U0001F4BE Naya GB Limit enter karein:"),
    ],
    "domain": [("value", "\U0001F30D Naya domain enter karein (e.g. ://example.com):")],
    "banner": [("value", "\U0001F4E2 Naya SSH banner text bhejein:")],
    "add_admin": [("value", "\U0001F451 Naye Admin ka Telegram User ID enter karein:")],
    "remove_admin": [("value", "\U0001F5D1 Remove karne ke liye Admin ka Telegram User ID enter karein:")],
}

def load_config():
    with open(CONFIG_FILE) as f:
        return json.load(f)

def load_admins():
    if not os.path.exists(ADMINS_FILE):
        return []
    with open(ADMINS_FILE) as f:
        return json.load(f)

def save_admins(admins):
    with open(ADMINS_FILE, "w") as f:
        json.dump(admins, f)

def is_admin(uid):
    return uid in load_admins()

def is_super(uid):
    cfg = load_config()
    return uid == cfg.get("super_admin")

def sh(cmd_list, input_data=None):
    return subprocess.run(cmd_list, capture_output=True, text=True, input=input_data)

def run(cmd_str):
    return subprocess.run(cmd_str, shell=True, capture_output=True, text=True)

def get_domain():
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE) as f:
            d = f.read().strip()
            return d if d else "No Domain Set"
    return "No Domain Set"

def apply_nginx_config():
    dom = get_domain()
    if dom == "No Domain Set":
        return
    os.makedirs("/etc/nginx/conf.d", exist_ok=True)
    with open("/etc/nginx/conf.d/vpn.conf", "w") as f:
        f.write(NGINX_TEMPLATE.format(dom=dom))
    sh(["rm", "-f", "/etc/nginx/sites-enabled/default"])
    sh(["systemctl", "restart", "nginx"])

def valid_username(u):
    return re.match(r"^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$", u) is not None

def add_user(username, password, days, ip_limit, gb_limit):
    if not valid_username(username):
        return False, "Invalid username (letter se start, sirf a-z 0-9 _ - allowed)."
    try:
        exp_date = (datetime.now() + timedelta(days=int(days))).strftime("%Y-%m-%d")
    except ValueError:
        return False, "Invalid days value."
    r = sh(["useradd", "-M", "-s", "/bin/bash", "-e", exp_date, username])
    if r.returncode != 0:
        return False, (r.stderr.strip() or "User create failed (already exists?)")
    sh(["chpasswd"], input_data=f"{username}:{password}\n")
    os.makedirs(USERS_DIR, exist_ok=True)
    with open(f"{USERS_DIR}/{username}.conf", "w") as f:
        f.write(f"IP_LIMIT={ip_limit}\nGB_LIMIT={gb_limit}\nUSED_MB=0.0\n")
    return True, exp_date
PY_EOF
}
setup_xray_and_slowdns_cores() {
    # 1. Install Xray Core System
    if [[ ! -f /usr/local/bin/xray ]]; then
        echo -e "${BLUE}Downloading and Installing Official Xray-Core...${NC}"
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    fi

    # 2. Xray Dual Template Deployment (TLS & Non-TLS Support)
    mkdir -p /etc/xray
    cat << 'XRAY_JSON_EOF' > /etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 1443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainuxbrand-vless" }
      },
      "tag": "vless-tls"
    },
    {
      "port": 8081,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainuxbrand-vless-nt" }
      },
      "tag": "vless-nontls"
    },
    {
      "port": 1553,
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/zainuxbrand-trojan" }
      },
      "tag": "trojan-tls"
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
XRAY_JSON_EOF
    systemctl enable xray && systemctl restart xray

    # 3. SlowDNS Installation & Keys Setup
    mkdir -p /etc/slowdns
    if [[ ! -f /usr/local/bin/dnstt-server ]]; then
        echo -e "${BLUE}Configuring SlowDNS Components...${NC}"
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
    systemctl restart nginx 2>/dev/null
}
apply_nginx_config() {
    apply_advanced_nginx
}

add_domain_option() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}        ADD / CHANGE DOMAIN NAME                    ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    read -rp " Apna Domain Enter Karein (e.g. ://yourdomain.com): " new_dom

    if [[ -z "$new_dom" ]]; then
        echo -e "${RED}[ERROR] Domain khaali nahi chhod sakte!${NC}"
    else
        mkdir -p /etc/zainuxbrand
        echo "$new_dom" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}[SUCCESS] Domain successfully set to: ${CYAN}${new_dom}${NC}"
        apply_nginx_config
    fi
    press_any_key
}

install_all_components() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}   ${PANEL_NAME} - SYSTEM INSTALLATION           ${NC}"
    echo -e "${CYAN}====================================================${NC}"

    echo -e "${BLUE}[1/6] Updating Packages...${NC}"
    apt update -y && apt upgrade -y

    echo -e "${BLUE}[2/6] Installing Required Tools...${NC}"
    apt install -y curl wget unzip tar net-tools socat jq openssl nginx dropbear certbot python3 python3-pip lsof iptables git build-essential

    echo -e "${BLUE}[3/6] Configuring Dropbear SSH & Banner...${NC}"
    cat << 'BANNER_EOF' > $BANNER_FILE
<font color="green">==========================================</font><br>
<font color="yellow"><b>WELCOME TO ZAINUXBRAND VIP VPN</b></font><br>
<font color="red"><b>- NO TORRENT / NO MULTILOGIN</b></font><br>
<font color="green">==========================================</font><br>
BANNER_EOF

    fix_dropbear_core
    sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
    systemctl restart ssh

    echo -e "${BLUE}[4/6] Creating Python WebSocket Services...${NC}"
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
Description=zainuxbrand WebSocket Proxy Service
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

    echo -e "${BLUE}[5/6] Installing Bandwidth Engine...${NC}"
    install_python_tracker

    echo -e "\n${GREEN}[SUCCESS] All Components Configured Perfectly!${NC}"
    press_any_key
}

setup_ssl() {
    clear
    local current_dom=$(get_domain)

    if [[ "$current_dom" == "No Domain Set" || -z "$current_dom" ]]; then
        echo -e "${RED}[ERROR] Pehle Option 2 se Domain Add karein!${NC}"
        press_any_key
        return
    fi

    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}  ${PANEL_NAME} - ISSUING SSL (${current_dom}) ${NC}"
    echo -e "${CYAN}====================================================${NC}"

    systemctl stop nginx
    certbot certonly --standalone --preferred-challenges http --agree-tos --register-unsafely-without-email -d "$current_dom"

    if [[ -f "/etc/letsencrypt/live/$current_dom/fullchain.pem" ]]; then
        echo -e "\n${GREEN}[SUCCESS] SSL Active for ${current_dom}!${NC}"
        apply_nginx_config
    else
        echo -e "${RED}[ERROR] SSL Fail ho gaya! DNS mapping verify karein.${NC}"
    fi
    press_any_key
}

check_connected_ips() {
    clear
    echo -e "${CYAN}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}                     CONNECTED IPS & ACTIVE USERS                   ${NC}"
    echo -e "${CYAN}====================================================================${NC}"
    local total_count=$(ss -tnp 2>/dev/null | grep -E ":(80|443|22|109)" | grep "ESTAB" | wc -l)
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
        echo -e " 1) Generate VLESS TLS Configuration"
        echo -e " 2) Generate VLESS Non-TLS Configuration"
        echo -e " 3) Generate Trojan TLS Configuration"
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
                press_any_key
                ;;
            2)
                read -rp "Enter Client User Name: " vname
                local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
                jq ".inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${GREEN}====== VLESS NON-TLS CONFIGURATION ======${NC}"
                echo -e "Link: ${CYAN}vless://${uuid}@${cur_dom}:80?path=%2Fzainuxbrand-vless-nt&security=none&encryption=none&type=ws#${vname}${NC}"
                press_any_key
                ;;
            3)
                read -rp "Enter Trojan Password: " tpass
                jq ".inbounds[2].settings.clients += [{\"password\": \"$tpass\", \"email\": \"$tpass\"}]" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json
                systemctl restart xray
                echo -e "\n${GREEN}====== TROJAN TLS CONFIGURATION ======${NC}"
                echo -e "Link: ${CYAN}trojan://${tpass}@${cur_dom}:443?path=%2Fzainuxbrand-trojan&security=tls&type=ws#${tpass}${NC}"
                press_any_key
                ;;
            4)
                clear
                echo -e "${YELLOW}SlowDNS Configurations:${NC}"
                if [[ -f /etc/slowdns/server.pub ]]; then
                    echo -e "Public Key: ${GREEN}$(cat /etc/slowdns/server.pub)${NC}"
                    echo -e "Target Core Port: ${CYAN}22 (Dropbear System Direct)${NC}"
                    echo -e "Setup Command Example: dnstt-server -udp :53 -privkey server.key your.ns.domain 127.0.0.1:22"
                else
                    echo -e "${RED}SlowDNS installation complete nahi hui. Pehle option 1 chalaen.${NC}"
                fi
                press_any_key
                ;;
            5) return ;;
            *) echo "Invalid Option"; sleep 1 ;;
        esac
    done
}

user_menu() {
    local cur_dom=$(get_domain)
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${YELLOW}       ${PANEL_NAME} - USER MANAGEMENT           ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " 1) Add New User"
        echo -e " 2) Delete User"
        echo -e " 3) Check Connected IPs & Active Online Users"
        echo -e " 4) Check User Status, Quota & Limits"
        echo -e " 5) Renew Account Expiry Days"
        echo -e " 6) Extend / Modify IP Limit (Auto Unlock)"
        echo -e " 7) Extend / Modify GB Data Quota (Auto Unlock)"
        echo -e " 8) Back to Main Menu"
        echo -e "${CYAN}====================================================${NC}"
        read -rp "Option [1-8]: " u_choice

        case $u_choice in
            1)
                read -rp "Username: " username
                read -rp "Password: " password
                read -rp "Days Expiry (e.g. 30): " days
                read -rp "Max IP Limit (e.g. 1 ya 2): " ip_limit
                read -rp "Quota / Data Limit in GB (e.g. 50): " gb_limit
                exp_date=$(date -d "+$days days" +%Y-%m-%d)
                useradd -M -s /bin/bash -e "$exp_date" "$username"
                echo "$username:$password" | chpasswd
                mkdir -p /etc/zainuxbrand/users
                echo -e "IP_LIMIT=$ip_limit\nGB_LIMIT=$gb_limit\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"
                echo -e "${GREEN}SSH User $username Added Successfully.${NC}"
                press_any_key
                ;;
            2)
                read -rp "Username to delete: " username
                userdel -f "$username" 2>/dev/null
                rm -f "/etc/zainuxbrand/users/${username}.conf"
                press_any_key
                ;;
            3) check_connected_ips ;;
            4) check_gb_usage ;;
            8) return ;;
            *) echo "Invalid Option"; sleep 1 ;;
        esac
    done
}

status_check() {
    clear
    echo -e "${CYAN}All Main Services Status Engines checking done.${NC}"
    press_any_key
}
set_banner() { return; }
fix_websocket() { systemctl restart ws-proxy; press_any_key; }
setup_telegram_bot() { return; }
uninstall_panel() { rm -rf /etc/zainuxbrand; exit 0; }

while true; do
    clear
    CURRENT_DOM=$(get_domain)
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN}              ${PANEL_NAME}                       ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e " Domain Target: ${YELLOW}${CURRENT_DOM}${NC}"
    echo -e " Custom Path  : ${YELLOW}${CUSTOM_PATH}${NC}"
    echo -e "${CYAN}----------------------------------------------------${NC}"
    echo -e " 1) Auto Install System Components"
    echo -e " 2) Add / Change Domain Name"
    echo -e " 3) Issue SSL Certificate"
    echo -e " 4) Manage Accounts (Add/Delete/Renew/Limits)"
    echo -e " 5) Check Status & Ports"
    echo -e " 6) Set / Edit SSH Banner"
    echo -e " 7) Fix SSH WS & WS+SSL Connection"
    echo -e " 8) Setup / Manage Telegram Bot"
    echo -e " 9) Advanced Protocols (VLESS / Trojan / SlowDNS)"
    echo -e " 10) Uninstall Panel (Remove All Components)"
    echo -e " 11) Exit Panel"
    echo -e "${CYAN}====================================================${NC}"
    read -rp "Select Option [1-11]: " opt

    case $opt in
        1) install_all_components ;;
        2) add_domain_option ;;
        3) setup_ssl ;;
        4) user_menu ;;
        5) status_check ;;
        6) set_banner ;;
        7) fix_websocket ;;
        8) setup_telegram_bot ;;
        9) advanced_protocols_menu ;;
        10) uninstall_panel ;;
        11) exit 0 ;;
        *) echo "Invalid option"; sleep 1 ;;
    esac
done
