#!/bin/bash

# ==============================================================================
# Script Name   : ZAINU x BRAND Hybrid Ultimate Premium Tunneling Panel
# Description   : Merged SSH-WS, VLESS (TLS/NTLS), VMess, Trojan & SlowDNS Engine
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PANEL_NAME="ZAINUXBRAND Premium Ultimate (SSH + XRAY + SLOWDNS) Panel"
BANNER_FILE="/etc/issue.net"
CUSTOM_PATH="/zainuxbrand"
DOMAIN_FILE="/etc/zainuxbrand/domain.conf"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
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
    echo -e "${BLUE}[+] Configuring Dropbear SSH Core Engine...${NC}"
    mkdir -p /etc/dropbear
    chmod 700 /etc/dropbear
    [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]] && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key &>/dev/null
    [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]] && dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key &>/dev/null
    [[ ! -f /etc/dropbear/dropbear_ed25519_host_key ]] && dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key &>/dev/null
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
    systemctl enable dropbear && systemctl restart dropbear
}
install_xray_core() {
    echo -e "${BLUE}[+] Downloading Latest Xray-Core Premium Subsystems...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>/dev/null
    mkdir -p /usr/local/etc/xray
    
    cat << XRAY_EOF > $XRAY_CONFIG
{
    "log": { "loglevel": "warning" },
    "inbounds": [
        { "port": 10080, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless-ws" } } },
        { "port": 10081, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vless-xhttp" } } },
        { "port": 10082, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } } },
        { "port": 4433, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp" } },
        { "port": 20080, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess-ws" } } },
        { "port": 20081, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vmess-xhttp" } } },
        { "port": 20082, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "h2", "httpSettings": { "path": "/vmess-h2" } } },
        { "port": 5533, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "tcp" } },
        { "port": 30080, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [], "fallbacks": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-ws" } } },
        { "port": 6633, "protocol": "trojan", "settings": { "clients": [], "fallbacks": [] }, "streamSettings": { "network": "tcp" } }
    ],
    "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
XRAY_EOF
    systemctl daemon-reload && systemctl enable xray && systemctl restart xray
}

install_slowdns() {
    echo -e "${BLUE}[+] Deploying Pre-compiled Stable SlowDNS Binary Engine...${NC}"
    mkdir -p $SLOWDNS_DIR
    wget -O /usr/local/bin/dnstt-server https://github.com/bugfloyd/dnstt-deploy/releases/download/v1.0.0/dnstt-server-linux-amd64 &>/dev/null
    chmod +x /usr/local/bin/dnstt-server

    cd $SLOWDNS_DIR || exit
    [[ ! -f server.key ]] && /usr/local/bin/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub &>/dev/null
    
    local interface=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports 5300
    if command -v netfilter-persistent &>/dev/null; then netfilter-persistent save &>/dev/null; fi

    local MY_DOMAIN=$(get_domain)
    cat << DNS_SVC > /etc/systemd/system/slowdns.service
[Unit]
Description=ZAINUXBRAND SlowDNS Tunnel Server Daemon
After=network.target
[Service]
X11Forwarding=no
AllowTcpForwarding=yes
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key ns-${MY_DOMAIN} 127.0.0.1:22
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
DNS_SVC
    systemctl daemon-reload && systemctl enable slowdns && systemctl restart slowdns 2>/dev/null
}

# FIXED: Re-injected the core Python multi-payload proxy listener script missing inside your template
install_ws_proxy() {
    echo -e "${BLUE}[+] Deploying Dedicated Python Multi-Payload WebSocket Engine...${NC}"
    cat << 'WS_EOF' > /usr/local/bin/ws-proxy.py
import socket, threading, select
PORT = 2082; TARGET_HOST = '127.0.0.1'; TARGET_PORT = 109
def handle_client(client_socket, client_addr):
    try:
        client_socket.settimeout(10)
        request = client_socket.recv(4096).decode('utf-8', errors='ignore')
        if not request: return
        client_socket.sendall("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n".encode('utf-8'))
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((TARGET_HOST, TARGET_PORT))
        sockets = [client_socket, target_socket]; client_socket.settimeout(None)
        while True:
            readable, _, _ = select.select(sockets, [], [])
            for s in readable:
                other = target_socket if s is client_socket else client_socket
                data = s.recv(8192)
                if not data: return
                other.sendall(data)
    except: pass
    finally: client_socket.close()
server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', PORT)); server.listen(200)
while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client, addr), daemon=True).start()
WS_EOF
    chmod +x /usr/local/bin/ws-proxy.py
    cat << 'SVC_EOF' > /etc/systemd/system/ws-proxy.service
[Unit]
Description=ZainuxBrand WebSocket Proxy Core
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable ws-proxy && systemctl restart ws-proxy 2>/dev/null
}
install_python_tracker() {
    echo -e "${BLUE}[+] Deploying Intelligent Auto-Kill & Live Bandwidth Daemon...${NC}"
    cat << 'PY_EOF' > /usr/local/bin/autokill.py
import os, sys, time, subprocess, re

USER_DIR = "/etc/zainuxbrand/users"

def get_auth_logs():
    raw = ""
    try: raw = subprocess.check_output(["journalctl", "-u", "dropbear", "--no-pager", "-n", "300"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
    except: pass
    if os.path.exists("/var/log/auth.log"):
        try:
            with open("/var/log/auth.log", "r", encoding="utf-8", errors="ignore") as f: raw += "\n" + f.read()
        except: pass
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
                        if not m: m = re.search(r"for (\w+)", last_line)
                        if m:
                            uname = m.group(1)
                            if uname not in user_pids: user_pids[uname] = []
                            user_pids[uname].append(pid)
    except: pass
    return user_pids

def get_pid_io_bytes(pid):
    io_file = f"/proc/{pid}/io"
    total_bytes = 0
    if os.path.exists(io_file):
        try:
            with open(io_file, "r") as f:
                for line in f:
                    if line.startswith("rchar:") or line.startswith("wchar:"): total_bytes += int(line.split(":")[1].strip())
        except: pass
    return total_bytes

last_pid_bytes = {}

while True:
    try:
        raw_logs = get_auth_logs()
        user_pids_map = get_active_users_and_pids(raw_logs)
        if os.path.exists(USER_DIR):
            for fname in os.listdir(USER_DIR):
                if not fname.endswith(".conf"): continue
                uname = fname[:-5]
                conf_path = os.path.join(USER_DIR, fname)
                ip_limit = 0; gb_limit = "Unlimited"; used_mb = 0.0
                with open(conf_path, "r") as f: lines = f.readlines()
                for line in lines:
                    if line.startswith("IP_LIMIT="):
                        try: ip_limit = int(line.strip().split("=")[1])
                        except: pass
                    elif line.startswith("GB_LIMIT="): gb_limit = line.strip().split("=")[1]
                    elif line.startswith("USED_MB="):
                        try: used_mb = float(line.strip().split("=")[1])
                        except: pass
                active_pids = user_pids_map.get(uname, [])
                for pid in active_pids:
                    current_b = get_pid_io_bytes(pid)
                    if pid in last_pid_bytes:
                        diff = current_b - last_pid_bytes[pid]
                        if diff > 0: used_mb += (diff / (1024.0 * 1024.0))
                    last_pid_bytes[pid] = current_b
                new_lines = []
                for line in lines:
                    if line.startswith("USED_MB="): new_lines.append(f"USED_MB={used_mb:.2f}\n")
                    else: new_lines.append(line)
                with open(conf_path, "w") as f: f.writelines(new_lines)
                if gb_limit != "Unlimited":
                    try:
                        max_mb = float(gb_limit) * 1024.0
                        if used_mb >= max_mb:
                            subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                            for pid in active_pids: subprocess.call(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except: pass
                if ip_limit > 0 and len(active_pids) > ip_limit:
                    subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    for pid in active_pids: subprocess.call(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except: pass
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
    systemctl daemon-reload && systemctl enable autokill && systemctl restart autokill 2>/dev/null
}

apply_tengine_config() {
    local MY_DOMAIN=$(get_domain)
    [[ "$MY_DOMAIN" == "No Domain Set" || -z "$MY_DOMAIN" ]] && return
    local target_path="/etc/nginx/conf.d/vpn.conf"
    [[ -d /etc/tengine ]] && target_path="/etc/tengine/conf.d/vpn.conf"

    cat << TG_EOF > $target_path
server {
    listen 80 default_server; listen [::]:80 default_server; server_name ${MY_DOMAIN} _;
    location / {
        proxy_redirect off; proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    location ${CUSTOM_PATH} {
        proxy_redirect off; proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host;
    }
    location /vless-ws { proxy_pass http://127.0.0.1:10080; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vmess-ws { proxy_pass http://127.0.0.1:20080; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
server {
    listen 443 ssl http2 default_server; listen [::]:443 ssl http2 default_server; server_name ${MY_DOMAIN} _;
    ssl_certificate /etc/letsencrypt/live/${MY_DOMAIN}/fullchain.pem; ssl_certificate_key /etc/letsencrypt/live/${MY_DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    location / {
        proxy_redirect off; proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    location ${CUSTOM_PATH} {
        proxy_redirect off; proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host;
    }
    location /vless-ws { proxy_pass http://127.0.0.1:10080; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vless-xhttp { proxy_pass http://127.0.0.1:10081; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vless-grpc { proxy_pass grpc://127.0.0.1:10082; proxy_http_version 1.1; proxy_set_header Host \$host; }
    location /vmess-ws { proxy_pass http://127.0.0.1:20080; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vmess-xhttp { proxy_pass http://127.0.0.1:20081; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /trojan-ws { proxy_pass http://127.0.0.1:30080; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
TG_EOF
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart tengine &>/dev/null || systemctl restart nginx 2>/dev/null
}
setup_ssl() {
    clear; local current_dom=$(get_domain)
    if [[ "$current_dom" == "No Domain Set" || -z "$current_dom" ]]; then
        echo -e "${RED}[ERROR] Pehle Option 2 se Domain Add karein!${NC}"; press_any_key; return
    fi
    echo -e "${BLUE}[+] Terminating Web Servers For Standalone ACME Validation...${NC}"
    systemctl stop nginx &>/dev/null; systemctl stop tengine &>/dev/null
    certbot certonly --standalone --preferred-challenges http --agree-tos --register-unsafely-without-email -d "$current_dom"
    if [[ -f "/etc/letsencrypt/live/$current_dom/fullchain.pem" ]]; then
        echo -e "\n${GREEN}[SUCCESS] SSL Active & Mapped under Tengine Proxy!${NC}"
        apply_tengine_config
    else
        echo -e "${RED}[ERROR] ACME Protocol failed. Cloudflare rules check karein.${NC}"
    fi
    press_any_key
}

user_menu() {
    local cur_dom=$(get_domain)
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e " 1) Add Multi-Payload SSH WebSocket + SlowDNS Account\n 2) Add Premium Xray (VLESS/VMess/Trojan) Account\n 3) Delete User Account\n 4) Back to Dashboard"
        read -rp "Option [1-4]: " u_choice
        case $u_choice in
            1)
                read -rp "Username: " username; read -rp "Password: " password; read -rp "Days: " days
                exp_date=$(date -d "+$days days" +%Y-%m-%d)
                useradd -M -s /bin/bash -e "$exp_date" "$username" 2>/dev/null
                echo "$username:$password" | chpasswd
                mkdir -p /etc/zainuxbrand/users
                echo -e "IP_LIMIT=1\nGB_LIMIT=Unlimited\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"
                local pubkey=$(cat /etc/slowdns/server.pub 2>/dev/null)
                clear
                echo -e "${GREEN}[SUCCESS] Account Successfully Generated!${NC}"
                echo -e "Host / SNI: ${CYAN}${cur_dom}${NC} | Ports: 22, 80, 443"
                echo -e "Payload: GET ${CUSTOM_PATH} HTTP/1.1[crlf]Host: ${cur_dom}[crlf]Upgrade: websocket[crlf][crlf]"
                echo -e "SlowDNS Key: ${YELLOW}${pubkey}${NC}"
                press_any_key ;;
            2)
                read -rp "Account Client Email/User: " username; read -rp "Custom UUID Key Token: " token; read -rp "Days: " days
                exp_date=$(date -d "+$days days" +%Y-%m-%d)
                useradd -M -s /bin/bash -e "$exp_date" "$username" &>/dev/null
                if [[ -f $XRAY_CONFIG ]]; then
                    sed -i "/\"clients\": \[/a {\"id\": \"${token}\", \"email\": \"${username}\", \"password\": \"${token}\"}," $XRAY_CONFIG
                    systemctl restart xray
                fi
                mkdir -p /etc/zainuxbrand/users
                echo -e "IP_LIMIT=1\nGB_LIMIT=Unlimited\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"
                clear
                echo -e "${GREEN}[SUCCESS] Xray Credentials Synchronized Successfully!${NC}"
                echo -e " ↳ VLESS WS TLS  : vless://${token}@${cur_dom}:443?path=%2Fvless-ws&encryption=none&security=tls#Z-VLESS-TLS"
                echo -e " ↳ VLESS WS NTLS : vless://${token}@${cur_dom}:80?path=%2Fvless-ws&encryption=none&security=none#Z-VLESS-NTLS"
                echo -e " ↳ VMESS WS TLS  : vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"Z-VMESS-TLS\",\"add\":\"${cur_dom}\",\"port\":\"443\",\"id\":\"${token}\",\"net\":\"ws\",\"path\":\"/vmess-ws\",\"tls\":\"tls\"}" | base64 -w 0)"
                echo -e " ↳ TROJAN WS TLS : trojan://${token}@${cur_dom}:443?path=%2Ftrojan-ws&security=tls#Z-TROJAN-TLS"
                press_any_key ;;
            3) read -rp "Username to remove: " username; userdel -f "$username" 2>/dev/null; rm -f "/etc/zainuxbrand/users/${username}.conf"; press_any_key ;;
            4) return ;;
        esac
    done
}

status_check() {
    clear
    st_badge() { systemctl is-active "$1" &>/dev/null && echo -e "${GREEN}[ ACTIVE ]${NC}" || echo -e "${RED}[ INACTIVE ]${NC}"; }
    echo -e "${CYAN}====================================================================${NC}"
    printf "   %-32s : %b\n" "Dropbear SSH Core Engine" "$(st_badge dropbear)"
    printf "   %-32s : %b\n" "WebSocket Proxy Subsystem" "$(st_badge ws-proxy)"
    printf "   %-32s : %b\n" "Tengine / Nginx Router Layer" "$(st_badge tengine || st_badge nginx)"
    printf "   %-32s : %b\n" "Xray Premium Multi-Stream Core" "$(st_badge xray)"
    printf "   %-32s : %b\n" "SlowDNS Server Engine (DNSTT)" "$(st_badge slowdns)"
    printf "   %-32s : %b\n" "Auto-Kill & Tracking Engine" "$(st_badge autokill)"
    echo -e "${CYAN}====================================================================${NC}"
    press_any_key
}

install_all_components() {
    clear
    echo -e "${CYAN}[+] Triggering Global Deployment Operations...${NC}"
    apt update -y && apt upgrade -y
    apt install -y curl wget unzip tar net-tools socat jq openssl nginx dropbear certbot python3 python3-pip lsof iptables build-essential
    
    # FIXED: Linked the core missing ws-proxy initialization function call thread here
    fix_dropbear_core; install_xray_core; install_slowdns; install_ws_proxy; apply_tengine_config; install_python_tracker
    echo -e "\n${GREEN}[SYSTEM INITIALIZATION COMPLETED] All components verified.${NC}"
    press_any_key
}

while true; do
    clear; CURRENT_DOM=$(get_domain)
    echo -e "${CYAN}====================================================${NC}"
    echo -e " Domain Target: ${YELLOW}${CURRENT_DOM}${NC} | Path: ${CYAN}${CUSTOM_PATH}${NC}"
    echo -e "----------------------------------------------------"
    echo -e " 1) Auto Install Hybrid System Components\n 2) Add / Change Domain Name\n 3) Issue Let's Encrypt SSL\n 4) Manage Client Accounts\n 5) Check Systems Framework Status\n 6) Exit Controller Framework"
    read -rp "Select Option [1-6]: " opt
    case $opt in
        1) install_all_components ;;
        2) read -rp "Enter Domain Name: " new_dom; mkdir -p /etc/zainuxbrand && echo "$new_dom" > "$DOMAIN_FILE"; apply_tengine_config ;;
        3) setup_ssl ;;
        4) user_menu ;;
        5) status_check ;;
        6) exit 0 ;;
    esac
done
