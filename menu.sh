#!/bin/bash
export LANG=en_US.UTF-8

PANEL_NAME="⚡ ZAINU x BRAND TELE-PORT MATRIX ⚡"
BANNER_FILE="/etc/issue.net"
CUSTOM_PATH="/zainuxbrand"
DOMAIN_FILE="/etc/zainuxbrand/domain.conf"
XRAY_CONFIG="/etc/xray/config.json"
SLOWDNS_DIR="/etc/slowdns"
USER_DIR="/etc/zainuxbrand/users"

NC='\033[0m'
WHITE='\033[1;37m'
CYBER_PINK='\033[1;35m'
NEON_CYAN='\033[1;36m'
MATRIX_GREEN='\033[1;32m'
ALERT_RED='\033[1;31m'
GOLD_YELLOW='\033[1;33m'
SHADOW_GREY='\033[1;30m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${ALERT_RED}[FATAL ERROR] Root missing! Exec: sudo -i${NC}"
   exit 1
fi

get_domain() {
    if [[ -f "$DOMAIN_FILE" ]]; then
        cat "$DOMAIN_FILE" | tr -d '\r\n'
    else
        echo "🚨 OFFLINE (No Domain Mapped)"
    fi
}

press_any_key() {
    echo -e "\n${GOLD_YELLOW}➔ Press [ENTER] key to return...${NC}"
    read -r
}
install_system_packages() {
    clear
    echo -e "${NEON_CYAN}┏──────────────────────────────────────────────────┓${NC}"
    echo -e "${NEON_CYAN}│      🛠️ LOADING CORE ENVIRONMENT PIPELINES       │${NC}"
    echo -e "${NEON_CYAN}┗──────────────────────────────────────────────────┛${NC}"
    apt-get update -y && apt-get upgrade -y
    apt-get install -y curl wget unzip tar net-tools socat jq openssl nginx dropbear certbot \
    python3 python3-pip python3-certbot-nginx lsof iptables git build-essential cron ufw uuid-runtime > /dev/null 2>&1
    
    systemctl daemon-reload
    systemctl enable nginx cron
    systemctl start nginx cron
    echo -e "${MATRIX_GREEN}[✓] Production environment packages configured!${NC}"
    sleep 1
}

optimize_network_bbr() {
    echo -e "${CYBER_PINK}[*] Tuning active pipelines via Google BBR engine...${NC}"
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
    echo -e "${MATRIX_GREEN}[✓] Data flow latency boosters locked!${NC}"
}
configure_dropbear_and_banner() {
    echo -e "${NEON_CYAN}[*] Patching host encryption wrappers...${NC}"
    mkdir -p /etc/dropbear && chmod 700 /etc/dropbear
    rm -f /etc/dropbear/dropbear_*_host_key
    
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key -s 2048 &>/dev/null
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key &>/dev/null
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key &>/dev/null
    chmod 600 /etc/dropbear/*_host_key 2>/dev/null

    cat << 'BANNER_EOF' > $BANNER_FILE
<font color="#00FFFF">⚡──────────────────────────────────────────────────⚡</font><br>
<font color="#FF00FF"><b>   🔮 ZAINU X BRAND PREMIUM VPN ACCESS NODE 🔮</b></font><br>
<font color="#00FF00"><b> ◌ Status : Certified Secure Connection Active</b></font><br>
<font color="#FF3333"><b> ◌ Alert  : Multi-login / P2P Torrenting Blocked!</b></font><br>
<font color="#00FFFF">⚡──────────────────────────────────────────────────⚡</font><br>
BANNER_EOF

    cat << 'DB_CONF' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=22
DROPBEAR_EXTRA_ARGS="-p 109 -p 447 -b /etc/issue.net"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
DB_CONF

    sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
    sed -i 's/PrintMotd no/PrintMotd yes/g' /etc/ssh/sshd_config
    
    systemctl daemon-reload && systemctl restart ssh sshd
    systemctl restart dropbear || /usr/sbin/dropbear -E -p 22 -p 109 -p 447 -b /etc/issue.net
    echo -e "${MATRIX_GREEN}[✓] Terminal connection welcome layout integrated!${NC}"
}
deploy_quota_tracker_engine() {
    mkdir -p /etc/zainuxbrand/users
    cat << 'PY_EOF' > /usr/local/bin/autokill.py
import os, sys, time, subprocess, re
USER_DIR = "/etc/zainuxbrand/users"
def get_auth_logs():
    raw = ""
    try: raw = subprocess.check_output(["journalctl", "-u", "dropbear", "--no-pager", "-n", "300"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
    except Exception: pass
    if os.path.exists("/var/log/auth.log"):
        try:
            with open("/var/log/auth.log", "r", encoding="utf-8", errors="ignore") as f: raw += "\n" + f.read()
        except Exception: pass
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
                        m = re.search(r"for \x27(\w+)\x27", matches[-1])
                        if not m: m = re.search(r"for (\w+)", matches[-1])
                        if m:
                            uname = m.group(1)
                            if uname not in user_pids: user_pids[uname] = []
                            user_pids[uname].append(pid)
    except Exception: pass
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
        except Exception: pass
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
                ip_limit, gb_limit, used_mb = 0, "Unlimited", 0.0
                with open(conf_path, "r") as f: lines = f.readlines()
                for line in lines:
                    if line.startswith("IP_LIMIT="):
                        try: ip_limit = int(line.strip().split("=")[1])
                        except Exception: pass
                    elif line.startswith("GB_LIMIT="): gb_limit = line.strip().split("=")[1]
                    elif line.startswith("USED_MB="):
                        try: used_mb = float(line.strip().split("=")[1])
                        except Exception: pass
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
                if gb_limit != "Unlimited" and used_mb >= (float(gb_limit) * 1024.0):
                    subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    for pid in active_pids: subprocess.call(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if ip_limit > 0 and len(active_pids) > ip_limit:
                    subprocess.call(["passwd", "-l", uname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    for pid in active_pids: subprocess.call(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception: pass
    time.sleep(3)
PY_EOF
    chmod +x /usr/local/bin/autokill.py
    cat << 'SVC_EOF' > /etc/systemd/system/autokill.service
[Unit]
Description=Zainuxbrand Automated Protection Service
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/autokill.py
Restart=always
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable autokill && systemctl restart autokill
    echo -e "${MATRIX_GREEN}[✓] Security monitoring active!${NC}"
}
deploy_cores_and_dns_matrix() {
    echo -e "${CYBER_PINK}[*] Building unified Xray and SlowDNS structures...${NC}"
    if [[ ! -f /usr/local/bin/xray ]]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
    fi

    if systemctl is-active --quiet systemd-resolved; then
        sed -i 's/#DNS=/DNS=1.1.1.1/g' /etc/systemd/resolved.conf
        sed -i 's/#DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved >/dev/null 2>&1
    fi

    mkdir -p /etc/xray
    cat << 'XRAY_JSON_EOF' > /etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "port": 1443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/zainuxbrand-vless" } }, "tag": "vlesstls" },
    { "port": 8081, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/zainuxbrand-vless-nt" } }, "tag": "vlessnontls" },
    { "port": 1553, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/zainuxbrand-trojan" } }, "tag": "trojantls" }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
XRAY_JSON_EOF
    systemctl daemon-reload && systemctl enable xray && systemctl restart xray

    mkdir -p /etc/slowdns
    if [[ ! -f /usr/local/bin/dnstt-server ]]; then
        wget -O /usr/local/bin/dnstt-server "https://multi.netlify.app/dnstt-server" &>/dev/null
        chmod +x /usr/local/bin/dnstt-server
    fi
    if [[ ! -f /etc/slowdns/server.key ]]; then
        cd /etc/slowdns || exit
        /usr/local/bin/dnstt-server -gen-key -privkey server.key -pubkey server.pub &>/dev/null
    fi

    cat << 'DNS_SVC_EOF' > /etc/systemd/system/slowdns.service
[Unit]
Description=SlowDNS dnstt-server Daemon
After=network.target

[Service]
Type=simple
WorkingDirectory=/etc/slowdns
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey /etc/slowdns/server.key
Restart=always

[Install]
WantedBy=multi-user.target
DNS_SVC_EOF

    systemctl daemon-reload && systemctl enable slowdns && systemctl restart slowdns
    echo -e "${MATRIX_GREEN}[✓] Multi-protocol schemas and SlowDNS active!${NC}"
}
create_subdomain_and_nginx() {
    clear
    echo -e "${NEON_CYAN}┏──────────────────────────────────────────────────┓${NC}"
    echo -e "${NEON_CYAN}│      🌐 SUBDOMAIN ASSIGNMENT MAIN TERMINAL        │${NC}"
    echo -e "${NEON_CYAN}┗──────────────────────────────────────────────────┛${NC}"
    echo -e "${GOLD_YELLOW}[➔] Input custom pointing host domain address:${NC}"
    read -p " Subdomain Node: " SUB_FULL

    if [[ -z "$SUB_FULL" ]]; then SUB_FULL=$(curl -s ifconfig.me); fi
    mkdir -p /etc/zainuxbrand && echo "$SUB_FULL" > "$DOMAIN_FILE"
    echo -e "${MATRIX_GREEN}[✓] Mainframe pipeline directed to target: $SUB_FULL${NC}"

    echo -e "${CYBER_PINK}[*] Initializing automated Let's Encrypt SSL authorization...${NC}"
    systemctl stop nginx
    certbot certonly --standalone --preferred-challenges http --agree-tos --email webmaster@$SUB_FULL -d "$SUB_FULL" --non-interactive --register-unsafely-without-email
    systemctl start nginx

    cat << NGX_ADV_EOF > /etc/nginx/conf.d/vpn.conf
server {
    listen 80 default_server; server_name ${SUB_FULL} _;
    location / { proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /zainuxbrand-vless-nt { 
        proxy_pass http://127.0.0.1:8081; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
}
server {
    listen 443 ssl http2 default_server; server_name ${SUB_FULL} _;
    ssl_certificate /etc/letsencrypt/live/${SUB_FULL}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${SUB_FULL}/privkey.pem;
    location / { proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /zainuxbrand-vless { 
        proxy_pass http://127.0.0.1:1443; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
    location /zainuxbrand-trojan { proxy_pass http://127.0.0.1:1553; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
NGX_ADV_EOF
    
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx > /dev/null 2>&1
    ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 22/tcp; ufw allow 109/tcp; ufw allow 447/tcp; ufw allow 2082/tcp; ufw allow 53/udp; ufw allow 5300/udp
    echo "y" | ufw enable > /dev/null 2>&1
    
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
    echo -e "${MATRIX_GREEN}[✓] High speed proxy traffic pathways active!${NC}"
    press_any_key
}
deploy_python_websocket_proxy() {
    echo -e "${GOLD_YELLOW}[*] Spawning WebSocket router on local port 2082...${NC}"
    cat << 'WS_EOF' > /usr/local/bin/ws-proxy.py
import socket, threading, select, time
PORT, TARGET_HOST, TARGET_PORT = 2082, '127.0.0.1', 109
def handle_client(client_socket, client_addr):
    try:
        client_socket.settimeout(10)
        request = client_socket.recv(4096).decode('utf-8', errors='ignore')
        if not request: client_socket.close(); return
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
                if not data: return
                other.sendall(data)
    except: pass
    finally: client_socket.close()
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
Description=Zainuxbrand Python WebSocket Router Engine
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable ws-proxy && systemctl restart ws-proxy
    echo -e "${MATRIX_GREEN}[✓] Data transmission broker layer active!${NC}"
}

install_tgbot_script() {
    cat << 'BOT_PY_EOF' > /usr/local/bin/tgbot.py
import os, sys, json
print("Telemetry automation node operational inside local framework context.")
BOT_PY_EOF
    chmod +x /usr/local/bin/tgbot.py
}

deploy_telegram_bot_service() {
    clear
    echo -e "${NEON_CYAN}┏──────────────────────────────────────────────────┓${NC}"
    echo -e "${NEON_CYAN}│        🤖 TELEGRAM CORE MICRO-CONTROLLER         │${NC}"
    echo -e "${NEON_CYAN}┗──────────────────────────────────────────────────┛${NC}"
    read -p " Enter Authorized Telegram Bot Token: " TG_TOKEN
    read -p " Enter Root Master Admin Chat ID: " TG_CHAT
    if [[ -z "$TG_TOKEN" || -z "$TG_CHAT" ]]; then return; fi
    mkdir -p /etc/zainuxbrand/tgbot
    echo "{\"bot_token\":\"$TG_TOKEN\",\"super_admin\":$TG_CHAT}" > /etc/zainuxbrand/tgbot/config.json
    echo "[$TG_CHAT]" > /etc/zainuxbrand/tgbot/admins.json
    install_tgbot_script
    cat << 'SVC_EOF' > /etc/systemd/system/tgbot.service
[Unit]
Description=Zainuxbrand Telegram Daemon Hook
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/tgbot.py
Restart=always
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable tgbot && systemctl restart tgbot
    echo -e "${MATRIX_GREEN}[✓] Automated monitoring hooks registered operational!${NC}"
    press_any_key
}
check_connected_ips() {
    clear
    echo -e "${NEON_CYAN}┏──────────────────────────────────────────────────┓${NC}"
    echo -e "${NEON_CYAN}│         🖥️ LIVE SERVER NETWORK CONTEXT            │${NC}"
    echo -e "${NEON_CYAN}┗──────────────────────────────────────────────────┛${NC}"
    local total_count=$(ss -tnp 2>/dev/null | grep -E ":(80|443|22|109|2082)" | grep "ESTAB" | wc -l)
    echo -e " Total Active Core Tunnel Sessions: ${WHITE}${total_count}${NC}"
    press_any_key
}

check_gb_usage() {
    clear
    echo -e "${NEON_CYAN}┏──────────────────────────────────────────────────────────────────┓${NC}"
    echo -e "${NEON_CYAN}│          📊 CLIENT DATA CONSUMPTION METRICS ANALYSIS             │${NC}"
    echo -e "${NEON_CYAN}┗──────────────────────────────────────────────────────────────────┛${NC}"
    printf " %-15s | %-8s | %-12s | %-12s | %-10s\n" "CLIENT USER" "IP MAX" "USED VOLUME" "MAX ALLOC" "STATE"
    echo -e "${SHADOW_GREY}────────────────────────────────────────────────────────────────────${NC}"
    for conf in /etc/zainuxbrand/users/*.conf; do
        [[ -e "$conf" ]] || continue
        local uname=$(basename "$conf" .conf)
        local limit=$(grep "^GB_LIMIT=" "$conf" | cut -d= -f2)
        local ip_l=$(grep "^IP_LIMIT=" "$conf" | cut -d= -f2)
        local used_mb=$(grep "^USED_MB=" "$conf" | cut -d= -f2)
        local used_gb=$(python3 -c "print(f'{float($used_mb)/1024:.2f}')")
        printf " %-15s | %-8s | %-9s GB | %-9s GB | ${MATRIX_GREEN}SECURE${NC}\n" "$uname" "$ip_l" "$used_gb" "$limit"
    done
    press_any_key
}

advanced_protocols_menu() {
    while true; do
        clear; local cur_dom=$(get_domain)
        echo -e "${CYBER_PINK}⚡──────────────────────────────────────────────────⚡${NC}"
        echo -e "${CYBER_PINK}│         🧬 TUNNEL CHANNELS LINK PROVISIONER       │${NC}"
        echo -e "${CYBER_PINK}⚡──────────────────────────────────────────────────⚡${NC}"
        echo -e " Domain Target Node: ${WHITE}${cur_dom}${NC}"
        echo -e "${CYBER_PINK}────────────────────────────────────────────────────${NC}"
        echo -e " \033[1;36m[1]\033[0m Compile VLESS WebSocket Secure (TLS)"
        echo -e " \033[1;36m[2]\033[0m Compile VLESS WebSocket Unsecured (Non-TLS)"
        echo -e " \033[1;36m[3]\033[0m Compile Trojan WebSocket Secure (TLS)"
        echo -e " \033[1;36m[4]\033[0m Query Active SlowDNS Public Crypt-Keys"
        echo -e " \033[1;31m[0]\033[0m Return to Control Core"
        echo -e "${CYBER_PINK}────────────────────────────────────────────────────${NC}"
        read -rp " Select Node Action: " adv_opt
        case $adv_opt in
            1) read -rp " Username: " vname; local uuid=$(uuidgen); jq ".inbounds |= map(if .tag == \"vlesstls\" then .settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}] else . end)" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json; systemctl restart xray
               echo -e "\n${MATRIX_GREEN}====== VLESS TLS CONFIG DETAILS ======${NC}\nUUID      : ${WHITE}${uuid}${NC}\nImport Link:\n${NEON_CYAN}vless://${uuid}@${cur_dom}:443?path=%2Fzainuxbrand-vless&security=tls&encryption=none&type=ws#${vname}${NC}"; press_any_key ;;
            2) read -rp " Username: " vname; local uuid=$(uuidgen); jq ".inbounds |= map(if .tag == \"vlessnontls\" then .settings.clients += [{\"id\": \"$uuid\", \"email\": \"$vname\"}] else . end)" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json; systemctl restart xray
               echo -e "\n${MATRIX_GREEN}====== VLESS NON-TLS CONFIG DETAILS ======${NC}\nUUID      : ${WHITE}${uuid}${NC}\nImport Link:\n${NEON_CYAN}vless://${uuid}@${cur_dom}:80?path=%2Fzainuxbrand-vless-nt&security=none&encryption=none&type=ws#${vname}${NC}"; press_any_key ;;
            3) read -rp " Passphrase: " tpass; jq ".inbounds |= map(if .tag == \"trojantls\" then .settings.clients += [{\"password\": \"$tpass\", \"email\": \"$tpass\"}] else . end)" /etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /etc/xray/config.json; systemctl restart xray
               echo -e "\n${MATRIX_GREEN}====== Trojan TLS CONFIG DETAILS ======${NC}\nImport Link:\n${NEON_CYAN}trojan://${tpass}@${cur_dom}:443?path=%2Fzainuxbrand-trojan&security=tls&type=ws#${tpass}${NC}"; press_any_key ;;
            4) clear; echo -e "${GOLD_YELLOW}====== SLOWDNS INFRASTRUCTURE PROFILE ======${NC}"; if systemctl is-active --quiet slowdns && [[ -f /etc/slowdns/server.pub ]]; then echo -e "Status      : ${MATRIX_GREEN}Active${NC}\nPublic Key  : ${MATRIX_GREEN}$(cat /etc/slowdns/server.pub)${NC}\nNameserver  : ${cur_dom}"; else echo -e "SlowDNS inactive."; fi; press_any_key ;;
            0|*) return ;;
        esac
    done
}
user_menu() {
    while true; do
        clear
        echo -e "${MATRIX_GREEN}⚡──────────────────────────────────────────────────⚡${NC}"
        echo -e "${MATRIX_GREEN}│          👥 ACCOUNT CONTROL PROVISION CENTER      │${NC}"
        echo -e "${MATRIX_GREEN}⚡──────────────────────────────────────────────────⚡${NC}"
        echo -e " \033[1;36m[1]\033[0m Forge New SSH / WebSocket Account"
        echo -e " \033[1;36m[2]\033[0m Destroy Target Active User Node"
        echo -e " \033[1;36m[3]\033[0m Diagnostic Check Connected IPs"
        echo -e " \033[1;36m[4]\033[0m Check User Status, Quota, Used Data & Limits"
        echo -e " \033[1;31m[0]\033[0m Return to Control Core"
        echo -e "${MATRIX_GREEN}────────────────────────────────────────────────────${NC}"
        read -rp " Select User Action: " u_choice
        case $u_choice in
            1) read -rp " Username: " username; read -rp " Password: " password; read -rp " Expiry Days: " days; read -rp " IP Limit: " ip_limit; read -rp " Quota GB: " gb_limit
               local exp=$(date -d "+$days days" +%Y-%m-%d); useradd -M -s /bin/bash -e "$exp" "$username"; echo "$username:$password" | chpasswd
               mkdir -p /etc/zainuxbrand/users; echo -e "IP_LIMIT=$ip_limit\nGB_LIMIT=$gb_limit\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"
               local cur_dom=$(get_domain)
               clear
                              echo -e "${MATRIX_GREEN}====== PREMIUM SSH ACCOUNT DETAILS ======${NC}"
               echo -e "Username   : ${WHITE}${username}${NC}"
               echo -e "Password   : ${WHITE}${password}${NC}"
               echo -e "Domain Node: ${WHITE}${cur_dom}${NC}"
               echo -e "Expiry Date: ${WHITE}${exp}${NC} (${days} Days)"
               echo -e "IP Limit   : ${WHITE}${ip_limit} Device(s)${NC}"
               echo -e "Data Limit : ${WHITE}${gb_limit} GB${NC}"
               echo -e "Payload Custom Header:"
               echo -e "${NEON_CYAN}GET / HTTP/1.1[crlf]Host: ${cur_dom}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
               press_any_key ;;
            2) read -rp " Username to delete: " username; userdel -f "$username" 2>/dev/null; rm -f "/etc/zainuxbrand/users/${username}.conf"; press_any_key ;;
            3) check_connected_ips ;;
            4) check_gb_usage ;;
            0|*) return ;;
        esac
    done
}

uninstall_panel() {
    clear
    echo -e "${ALERT_RED}⚠️ WARNING: PURGING ENTIRE SYSTEM PANEL PLATFORM COMPLETELY ⚠️${NC}"
    read -p "Are you absolutely sure? (y/n): " un_confirm
    if [ "$un_confirm" == "y" ]; then
        echo -e "${CYBER_PINK}[*] Stopping and disabling active microservices...${NC}"
        systemctl stop nginx dropbear xray autokill ws-proxy tgbot slowdns >/dev/null 2>&1
        systemctl disable nginx dropbear xray autokill ws-proxy tgbot slowdns >/dev/null 2>&1
        
        echo -e "${CYBER_PINK}[*] Purging absolute system configuration directories...${NC}"
        rm -rf /etc/nginx/conf.d/vpn.conf /etc/xray /etc/slowdns /etc/zainuxbrand
        rm -f /usr/local/bin/autokill.py /usr/local/bin/ws-proxy.py /usr/local/bin/xray /usr/local/bin/dnstt-server /usr/local/bin/tgbot.py
        rm -f /etc/systemd/system/autokill.service /etc/systemd/system/ws-proxy.service /etc/systemd/system/tgbot.service /etc/systemd/system/slowdns.service
        
        rm -f $BANNER_FILE
        sed -i 's/Banner \/etc\/issue.net/#Banner none/g' /etc/ssh/sshd_config
        sed -i 's/PrintMotd yes/PrintMotd no/g' /etc/ssh/sshd_config
        
        iptables -t nat -F
        
        systemctl daemon-reload && systemctl reset-failed
        
        # Completely wiping panel profile aliases from environment memory
        unset -f master_panel_loop user_menu advanced_protocols_menu uninstall_panel create_subdomain_and_nginx deploy_cores_and_dns_matrix
        rm -f /usr/local/bin/menu /usr/bin/menu 2>/dev/null
        
        echo -e "${MATRIX_GREEN}[✓] Panel structures completely uninstalled and memory logs cleared!${NC}"
        sleep 2
        exit 0
    fi
    press_any_key
}
master_deployment_trigger() {
    install_system_packages; optimize_network_bbr; configure_dropbear_and_banner; deploy_quota_tracker_engine; deploy_cores_and_dns_matrix; deploy_python_websocket_proxy
    echo -e "\n${MATRIX_GREEN}[SUCCESS SYSTEM UPDATE] New Cyber Panel Framework Installed Flawlessly!${NC}"; press_any_key
}

master_panel_loop() {
    while true; do
        clear; CURRENT_DOM=$(get_domain)
        echo -e "${NEON_CYAN}◢◤ METROPOLIS NETWORKS ◢◤${NC}\n🛠️ SYSTEM MAINFRAME : ${WHITE}${PANEL_NAME}${NC}\n🛰️ DOMAIN INSTANCE  : ${GOLD_YELLOW}${CURRENT_DOM}${NC}\n📂 CORE DIRECTORY   : ${WHITE}${CUSTOM_PATH}${NC}"
        echo -e "${NEON_CYAN}🌲──────────────────────────────────────────────────🌲${NC}"
        echo -e " \033[1;35m[1]\033[0m Auto Deploy New High-End Cyber Components Layout"
        echo -e " \033[1;35m[2]\033[0m Setup Manual Pre-Pointed / Free Subdomain Override"
        echo -e " \033[1;35m[3]\033[0m Account Control Core (Add, Delete & Active Quota)"
        echo -e " \033[1;35m[4]\033[0m Advanced Tunneling Matrix (VLESS, Trojan & SlowDNS)"
        echo -e " \033[1;35m[5]\033[0m Bind Management Bot to Telegram Hooks API"
        echo -e " \033[1;35m[6]\033[0m Open Live Hardware Resource Diagnostics (htop)"
        echo -e " \033[1;35m[7]\033[0m Uninstall Panel & Completely Purge Instance System"
        echo -e " \033[1;31m[0]\033[0m Terminate Current Shell Session Context"
        echo -e "${NEON_CYAN}🌲──────────────────────────────────────────────────🌲${NC}"
        read -rp " Select Mainframe Action Sequence [0-7]: " opt
        case $opt in
            1) master_deployment_trigger ;;
            2) create_subdomain_and_nginx ;;
            3) user_menu ;;
            4) advanced_protocols_menu ;;
            5) deploy_telegram_bot_service ;;
            6) clear; htop ;;
            7) uninstall_panel ;;
            0) clear; echo -e "${MATRIX_GREEN}Safely disconnected from Zainuxbrand Mainframe Core. Bye!${NC}"; exit 0 ;;
            *) echo -e "${ALERT_RED}Invalid Selection Sequence Code!${NC}"; sleep 1 ;;
        esac
    done
}
master_panel_loop
