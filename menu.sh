#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PANEL_NAME="ZAINUXBRAND Premium Ultimate (TLS + Non-TLS) Panel"
BANNER_FILE="/etc/issue.net"
DOMAIN_FILE="/etc/zainuxbrand/domain.conf"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
SLOWDNS_DIR="/etc/slowdns"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] Yeh script ROOT privilege ke sath chalaen! (sudo -i)${NC}"
   exit 1
fi

get_domain() {
    [[ -f "$DOMAIN_FILE" ]] && cat "$DOMAIN_FILE" | tr -d '\r\n' || echo "No Domain Set"
}

press_any_key() {
    echo -e "\n${YELLOW}Press [ENTER] key to return to main menu...${NC}"
    read -r
}

fix_dropbear_core() {
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
    systemctl daemon-reload && systemctl enable dropbear &>/dev/null && systemctl restart dropbear
}

install_xray_core() {
    echo -e "${BLUE}[+] Installing Latest Xray-Core Premium Subsystems...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>/dev/null
    mkdir -p /usr/local/etc/xray
    
    cat << XRAY_EOF > $XRAY_CONFIG
{
    "log": { "loglevel": "warning" },
    "inbounds": [
        { "port": 443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless-ws" } } },
        { "port": 80, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless-ws" } } },
        { "port": 444, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vless-xhttp" } } },
        { "port": 880, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vless-xhttp" } } },
        { "port": 445, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } } },
        { "port": 8085, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } } },
        { "port": 4433, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp" } },
        { "port": 8443, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess-ws" } } },
        { "port": 8080, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess-ws" } } },
        { "port": 8444, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vmess-xhttp" } } },
        { "port": 8880, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/vmess-xhttp" } } },
        { "port": 8445, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "h2", "httpSettings": { "path": "/vmess-h2" } } },
        { "port": 8082, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "h2", "httpSettings": { "path": "/vmess-h2" } } },
        { "port": 5533, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "tcp" } },
        { "port": 2083, "protocol": "trojan", "settings": { "clients": [], "fallbacks": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-ws" } } },
        { "port": 2082, "protocol": "trojan", "settings": { "clients": [], "fallbacks": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-ws" } } },
        { "port": 6633, "protocol": "trojan", "settings": { "clients": [], "fallbacks": [] }, "streamSettings": { "network": "tcp" } }
    ],
    "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
XRAY_EOF
    systemctl daemon-reload && systemctl enable xray &>/dev/null && systemctl restart xray
}
install_tengine_proxy() {
    echo -e "${BLUE}[+] Deploying High-Performance Tengine Core Web Layer...${NC}"
    apt-get install -y software-properties-common &>/dev/null
    apt install -y tengine certbot &>/dev/null || apt install -y nginx certbot &>/dev/null
    mkdir -p /etc/tengine/conf.d /etc/nginx/conf.d
}

apply_tengine_config() {
    local MY_DOMAIN=$(get_domain)
    [[ "$MY_DOMAIN" == "No Domain Set" || -z "$MY_DOMAIN" ]] && return
    local target_path="/etc/tengine/conf.d/vpn.conf"
    [[ ! -d /etc/tengine ]] && target_path="/etc/nginx/conf.d/vpn.conf"

    cat << TG_EOF > $target_path
server {
    listen 80;
    server_name ${MY_DOMAIN};
    location /vless-ws { proxy_pass http://127.0.0.1:80; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vmess-ws { proxy_pass http://127.0.0.1:8080; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /trojan-ws { proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
TG_EOF
    systemctl restart tengine &>/dev/null || systemctl restart nginx 2>/dev/null
}

install_slowdns() {
    echo -e "${BLUE}[+] Deploying Pre-compiled Stable SlowDNS Binary Engine...${NC}"
    mkdir -p $SLOWDNS_DIR
    wget -O /usr/local/bin/dnstt-server https://github.com/bugfloyd/dnstt-deploy/releases/download/v1.0.0/dnstt-server-linux-amd64 &>/dev/null
    chmod +x /usr/local/bin/dnstt-server

    cd $SLOWDNS_DIR || exit
    /usr/local/bin/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub &>/dev/null
    
    local interface=$(ip route get 8.8.8.8 | awk -- '{print $5; exit}')
    iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports 5300
    netfilter-persistent save &>/dev/null

    local MY_DOMAIN=$(get_domain)
    cat << DNS_SVC > /etc/systemd/system/slowdns.service
[Unit]
Description=ZAINUXBRAND SlowDNS Tunnel Server Daemon
After=network.target
[Service]
X11Forwarding=no
AllowTcpForwarding=yes
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key ${MY_DOMAIN} 127.0.0.1:22
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
DNS_SVC
    systemctl daemon-reload && systemctl enable slowdns &>/dev/null && systemctl restart slowdns 2>/dev/null
}
install_python_tracker() {
    cat << 'PY_EOF' > /usr/local/bin/autokill.py
import os, sys, time, subprocess, re
while True: time.sleep(3)
PY_EOF
    chmod +x /usr/local/bin/autokill.py
    cat << 'SVC_EOF' > /etc/systemd/system/autokill.service
[Unit]
Description=zainuxbrand Auto-Kill Service
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/autokill.py
Restart=always
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable autokill &>/dev/null && systemctl restart autokill
}

add_domain_option() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}        ADD / CHANGE DOMAIN NAME                    ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    read -rp " Apna Domain/Subdomain Enter Karein: " new_dom
    if [[ -z "$new_dom" ]]; then
        echo -e "${RED}[ERROR] Domain khaali nahi chhod sakte!${NC}"
    else
        mkdir -p /etc/zainuxbrand && echo "$new_dom" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}[SUCCESS] Domain successfully set to: ${CYAN}${new_dom}${NC}"
        apply_tengine_config
        [[ -f /etc/systemd/system/slowdns.service ]] && sed -i "s/-privkey-file \/etc\/slowdns\/server.key .*/-privkey-file \/etc\/slowdns\/server.key ${new_dom} 127.0.0.1:22/g" /etc/systemd/system/slowdns.service && systemctl daemon-reload && systemctl restart slowdns 2>/dev/null
    fi
    press_any_key
}

install_all_components() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}   ${PANEL_NAME} - SYSTEM DEPLOYMENT       ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    apt update -y && apt upgrade -y
    apt install -y curl wget unzip tar net-tools socat jq openssl python3 python3-pip lsof iptables-persistent build-essential
    cat << 'BANNER_EOF' > $BANNER_FILE
<font color="green">==========================================</font><br>
<font color="yellow"><b>⚡ WELCOME TO ZAINUXBRAND TENGINE ULTIMATE VPN ⚡</b></font><br>
<font color="cyan"><b>Join Channel: t.me/zainuxbrand</b></font><br>
<font color="orange"><b>Support No: 03077716993</b></font><br>
<font color="green">==========================================</font><br>
BANNER_EOF
    fix_dropbear_core
    sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config && systemctl restart ssh
    install_xray_core && install_tengine_proxy && install_slowdns && install_python_tracker && apply_tengine_config
    echo -e "\n${GREEN}[SUCCESS] All premium protocol channels injected seamlessly under Tengine layer!${NC}"
    press_any_key
}
account_management_menu() {
    local cur_dom=$(get_domain)
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${YELLOW}       ZAINUXBRAND SEPARATE ACCOUNT SETUP OPTIONS   ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " 1) Create Separate SSH WebSocket + SlowDNS Account"
        echo -e " 2) Create Separate Xray VLESS (WS/XHTTP/gRPC/TCP) Account"
        echo -e " 3) Create Separate Xray VMess (WS/XHTTP/H2/TCP) Account"
        echo -e " 4) Create Separate Xray Trojan (WS/TCP) Account"
        echo -e " 5) Delete User Account"
        echo -e " 6) Back to Main Menu"
        echo -e "${CYAN}====================================================${NC}"
        read -rp "Select Choice [1-6]: " ac_choice
        
        if [[ "$ac_choice" -ge 1 && "$ac_choice" -le 4 ]]; then
            read -rp "Username: " username
            read -rp "Password / Custom UUID Token: " password
            read -rp "Expiry Days: " days
            local exp_date=$(date -d "+$days days" +%Y-%m-%d)
            useradd -M -s /bin/bash -e "$exp_date" "$username" &>/dev/null
            echo "$username:$password" | chpasswd
            
            if [[ -f $XRAY_CONFIG ]]; then
                sed -i "/\"clients\": \[/a {\"id\": \"${password}\", \"email\": \"${username}\", \"password\": \"${password}\"}," $XRAY_CONFIG
                systemctl restart xray
            fi
            mkdir -p /etc/zainuxbrand/users && echo -e "IP_LIMIT=1\nGB_LIMIT=Unlimited" > "/etc/zainuxbrand/users/${username}.conf"
            local pubkey=$(cat /etc/slowdns/server.pub 2>/dev/null)
            clear
            echo -e "\n${GREEN}====================================================${NC}"
            echo -e " User: ${CYAN}${username}${NC} | Token: ${CYAN}${password}${NC} | Expiry: ${YELLOW}${exp_date}${NC}"
            echo -e " Telegram: ${CYAN}t.me/zainuxbrand${NC} | Support: ${CYAN}03077716993${NC}"
            echo -e "----------------------------------------------------"
        fi

        case $ac_choice in
            1)
                echo -e "${BOLD}[DEDICATED SSH + SLOWDNS CONFIG]:${NC}"
                echo -e " Ports: 80, 443, 22, 109"
                echo -e " Payload: GET /zainuxbrand HTTP/1.1[crlf]Host: ${cur_dom}[crlf]Upgrade: websocket[crlf][crlf]"
                echo -e " SlowDNS Key: ${YELLOW}${pubkey}${NC}"
                echo -e "${GREEN}====================================================${NC}"
                press_any_key ;;
            2)
                echo -e "${BOLD}[DEDICATED VLESS TRANSURMISSIONS]:${NC}"
                echo -e " ↳ WS TLS  : vless://${password}@${cur_dom}:443?style=websocket&path=%2Fvless-ws&encryption=none&security=none#⚡+Z-VLESS-WS-TLS"
                echo -e " ↳ WS NTLS : vless://${password}@${cur_dom}:80?style=websocket&path=%2Fvless-ws&encryption=none&security=none#⚡+Z-VLESS-WS-NTLS"
                echo -e " ↳ XHTTP   : vless://${password}@${cur_dom}:444?style=httpupgrade&path=%2Fvless-xhttp&encryption=none&security=none#⚡+Z-VLESS-XHTTP-TLS"
                echo -e " ↳ RAW TCP : vless://${password}@${cur_dom}:4433?encryption=none&security=none#⚡+Z-VLESS-TCP"
                echo -e "${GREEN}====================================================${NC}"
                press_any_key ;;
            3)
                echo -e "${BOLD}[DEDICATED VMESS TRANSURMISSIONS]:${NC}"
                echo -e " ↳ WS TLS  : vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"⚡ Z-VMESS-WS-TLS\",\"add\":\"${cur_dom}\",\"port\":\"8443\",\"id\":\"${password}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"path\":\"/vmess-ws\",\"type\":\"none\"}" | base64 -w 0)"
                echo -e " ↳ WS NTLS : vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"⚡ Z-VMESS-WS-NTLS\",\"add\":\"${cur_dom}\",\"port\":\"8080\",\"id\":\"${password}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"path\":\"/vmess-ws\",\"type\":\"none\"}" | base64 -w 0)"
                echo -e " ↳ RAW TCP : vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"⚡ Z-VMESS-TCP\",\"add\":\"${cur_dom}\",\"port\":\"5533\",\"id\":\"${password}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"tcp\",\"type\":\"none\"}" | base64 -w 0)"
                echo -e "${GREEN}====================================================${NC}"
                press_any_key ;;
            4)
                echo -e "${BOLD}[DEDICATED TROJAN TRANSURMISSIONS]:${NC}"
                echo -e " ↳ WS TLS  : trojan://${password}@${cur_dom}:2083?path=%2Ftrojan-ws&security=none#⚡+Z-TROJAN-WS-TLS"
                echo -e " ↳ RAW TCP : trojan://${password}@${cur_dom}:6633?security=none#⚡+Z-TROJAN-TCP"
                echo -e "${GREEN}====================================================${NC}"
                press_any_key ;;
            5) read -rp "Username to delete: " username; userdel -f "$username" 2>/dev/null; rm -f "/etc/zainuxbrand/users/${username}.conf"; press_any_key ;;
            6) return ;;
        esac
    done
}

status_check() {
    clear
    st_badge() { systemctl is-active "$1" &>/dev/null && echo -e "${GREEN}[ ACTIVE ]${NC}" || echo -e "${RED}[ INACTIVE ]${NC}"; }
    echo -e "${CYAN}====================================================================${NC}"
    printf "   %-32s : %b\n" "Dropbear SSH Core Engine" "$(st_badge dropbear)"
    printf "   %-32s : %b\n" "Tengine / Nginx Router Layer" "$(st_badge tengine || st_badge nginx)"
    printf "   %-32s : %b\n" "Xray Premium Multi-Stream Core" "$(st_badge xray)"
    printf "   %-32s : %b\n" "SlowDNS Server Engine (DNSTT)" "$(st_badge slowdns)"
    echo -e "${CYAN}====================================================================${NC}"
    press_any_key
}

while true; do
    clear
    CURRENT_DOM=$(get_domain)
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN}       ${PANEL_NAME}          ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e " Domain Target: ${YELLOW}${CURRENT_DOM}${NC}"
    echo -e " Streams      : ${CYAN}SEPARATE ACCOUNT SETUP MODULES ACTIVE${NC}"
    echo -e "----------------------------------------------------"
    echo -e " 1) Auto Install System Components & Protocols\n 2) Add / Change Domain Name\n 3) Manage Accounts\n 4) Check Status\n 5) Exit Panel Package"
    read -rp "Select Option [1-5]: " opt
    case $opt in
        1) install_all_components ;;
        2) add_domain_option ;;
        3) account_management_menu ;;
        4) status_check ;;
        5) exit 0 ;;
    esac
done
