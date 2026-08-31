#!/bin/bash

# ==============================================================================
# Script Name   : ZAINU x BRAND Multi-Protocol Premium VPN Panel (PART 1)
# Custom Path   : /zainuxbrand
# Supported     : SSH, WebSocket, Xray (VLESS, VMess, Trojan), SlowDNS (DNSTT)
# Branding      : Fully Synchronized Dynamic Client Logging Banners
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PANEL_NAME="ZAINUXBRAND Multi-Protocol Panel"
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
    systemctl enable dropbear &>/dev/null
    systemctl restart dropbear
}

install_xray_core() {
    echo -e "${BLUE}[+] Installing Latest Xray-Core Engine...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>/dev/null
    
    mkdir -p /usr/local/etc/xray
    
    cat << XRAY_EOF > $XRAY_CONFIG
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 4433,
            "protocol": "vless",
            "settings": {
                "clients": [],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none"
            }
        },
        {
            "port": 5533,
            "protocol": "vmess",
            "settings": {
                "clients": []
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/vmess"
                }
            }
        },
        {
            "port": 6633,
            "protocol": "trojan",
            "settings": {
                "clients": [],
                "fallbacks": []
            },
            "streamSettings": {
                "network": "tcp"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
XRAY_EOF
    systemctl daemon-reload
    systemctl enable xray &>/dev/null
    systemctl restart xray
}
install_slowdns() {
    echo -e "${BLUE}[+] Setting up Go Language & Compiling SlowDNS...${NC}"
    apt install -y golang git build-essential iptables-persistent &>/dev/null
    
    mkdir -p $SLOWDNS_DIR
    cd /tmp || exit
    rm -rf dnstt
    git clone https://github.com/xtaci/dnstt.git &>/dev/null
    
    if [[ -d "dnstt/dnstt-server" ]]; then
        cd dnstt/dnstt-server || exit
        go build &>/dev/null
        cp dnstt-server /usr/local/bin/dnstt-server
        chmod +x /usr/local/bin/dnstt-server
    else
        echo -e "${RED}[ERROR] SlowDNS download fallback active...${NC}"
        wget -O /usr/local/bin/dnstt-server https://github.com/bugfloyd/dnstt-deploy/releases/download/v1.0.0/dnstt-server-linux-amd64 &>/dev/null
        chmod +x /usr/local/bin/dnstt-server
    fi

    cd $SLOWDNS_DIR || exit
    /usr/local/bin/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub &>/dev/null
    
    local interface=$(ip route get 8.8.8.8 | awk -- '{print $5; exit}')
    iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports 5300
    ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null
    
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

    systemctl daemon-reload
    systemctl enable slowdns &>/dev/null
    systemctl restart slowdns 2>/dev/null
}

install_python_tracker() {
    cat << 'PY_EOF' > /usr/local/bin/autokill.py
import os, sys, time, subprocess, re
USER_DIR = "/etc/zainuxbrand/users"
while True:
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
    systemctl enable autokill &>/dev/null
    systemctl restart autokill
}
apply_nginx_config() {
    local MY_DOMAIN=$(get_domain)
    if [[ "$MY_DOMAIN" == "No Domain Set" || -z "$MY_DOMAIN" ]]; then
        return
    fi

    cat << NGX_EOF > /etc/nginx/conf.d/vpn.conf
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
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ${CUSTOM_PATH} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGX_EOF
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx 2>/dev/null
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
        mkdir -p /etc/zainuxbrand
        echo "$new_dom" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}[SUCCESS] Domain successfully set to: ${CYAN}${new_dom}${NC}"
        apply_nginx_config
        
        if [[ -f /etc/systemd/system/slowdns.service ]]; then
            sed -i "s/-privkey-file \/etc\/slowdns\/server.key .*/-privkey-file \/etc\/slowdns\/server.key ${new_dom} 127.0.0.1:22/g" /etc/systemd/system/slowdns.service
            systemctl daemon-reload
            systemctl restart slowdns 2>/dev/null
        fi
    fi
    press_any_key
}

install_all_components() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}   ${PANEL_NAME} - COMPLETE DEPLOYMENT           ${NC}"
    echo -e "${CYAN}====================================================${NC}"

    echo -e "${BLUE}[1/6] Updating OS Core Repositories...${NC}"
    apt update -y && apt upgrade -y

    echo -e "${BLUE}[2/6] Installing Baseline Multi-Proxy Tools...${NC}"
    apt install -y curl wget unzip tar net-tools socat jq openssl nginx dropbear certbot python3 python3-pip lsof iptables

    echo -e "${BLUE}[3/6] Configuring SSH Core and Environments...${NC}"
    cat << 'BANNER_EOF' > $BANNER_FILE
<font color="green">==========================================</font><br>
<font color="yellow"><b>⚡ WELCOME TO ZAINUXBRAND VIP PREMIUM VPN ⚡</b></font><br>
<font color="cyan"><b>Join Channel: t.me/zainuxbrand</b></font><br>
<font color="orange"><b>Support No: 03077716993</b></font><br>
<font color="red"><b>- NO TORRENT / NO MULTILOGIN</b></font><br>
<font color="green">==========================================</font><br>
BANNER_EOF

    fix_dropbear_core
    sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
    systemctl restart ssh

    echo -e "${BLUE}[4/6] Deploying Python WebSocket Core Layer...${NC}"
    cat << 'WS_EOF' > /usr/local/bin/ws-proxy.py
import socket, threading, select, time
PORT = 2082
TARGET_HOST = '127.0.0.1'
TARGET_PORT = 109

def handle_client(client_socket, client_addr):
    try:
        client_socket.settimeout(10)
        request = client_socket.recv(4096).decode('utf-8', errors='ignore')
        if not request: return
        response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
        client_socket.sendall(response.encode('utf-8'))
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((TARGET_HOST, TARGET_PORT))
        sockets = [client_socket, target_socket]
        while True:
            r, _, _ = select.select(sockets, [], [])
            for s in r:
                other = target_socket if s is client_socket else client_socket
                data = s.recv(8192)
                if not data: return
                other.sendall(data)
    except Exception: pass
    finally: client_socket.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', PORT))
server.listen(200)
while True:
    c, a = server.accept()
    threading.Thread(target=handle_client, args=(c, a), daemon=True).start()
WS_EOF

    cat << 'SVC_EOF' > /etc/systemd/system/ws-proxy.service
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
    systemctl enable ws-proxy &>/dev/null
    systemctl restart ws-proxy
    
    echo -e "${BLUE}[5/6] Injecting Xray-Core Daemon Services...${NC}"
    install_xray_core

    echo -e "${BLUE}[6/6] Compiling and Launching SlowDNS Modules...${NC}"
    install_slowdns
    
    install_python_tracker
    apply_nginx_config

    echo -e "\n${GREEN}[SUCCESS] Full Multi-Protocol Core Engines Installed Successfully!${NC}"
    press_any_key
}
account_management_menu() {
    local cur_dom=$(get_domain)
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${YELLOW}       ZAINUXBRAND MULTI-PROTOCOL ACCOUNTS          ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " 1) Add Account (SSH + Xray + SlowDNS)"
        echo -e " 2) Delete User Account"
        echo -e " 3) Back to Main Menu"
        echo -e "${CYAN}====================================================${NC}"
        read -rp "Select Choice [1-3]: " ac_choice

        case $ac_choice in
            1)
                read -rp "Username: " username
                read -rp "Password / Custom Token: " password
                read -rp "Expiry Days (e.g. 30): " days

                local exp_date=$(date -d "+$days days" +%Y-%m-%d)
                useradd -M -s /bin/bash -e "$exp_date" "$username" &>/dev/null
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}[ERROR] User create nahi hua! (Username pehle se ho sakta hai).${NC}"
                    press_any_key
                    continue
                fi
                echo "$username:$password" | chpasswd

                if [[ -f $XRAY_CONFIG ]]; then
                    sed -i "/\"clients\": \[/a {\"id\": \"${password}\", \"email\": \"${username}\"}," $XRAY_CONFIG
                    systemctl restart xray
                fi

                mkdir -p /etc/zainuxbrand/users
                echo -e "IP_LIMIT=1\nGB_LIMIT=Unlimited\nUSED_MB=0.0" > "/etc/zainuxbrand/users/${username}.conf"

                local pubkey=""
                [[ -f /etc/slowdns/server.pub ]] && pubkey=$(cat /etc/slowdns/server.pub)

                clear
                echo -e "\n${GREEN}====================================================${NC}"
                echo -e "${YELLOW}       MULTI-ACCOUNT ACTIVATED BY ZAINUXBRAND       ${NC}"
                echo -e "${GREEN}====================================================${NC}"
                echo -e " Target Domain : ${CYAN}${cur_dom}${NC}"
                echo -e " Username/Token: ${CYAN}${username}${NC}"
                echo -e " Password      : ${CYAN}${password}${NC}"
                echo -e " Expiry Date   : ${CYAN}${exp_date}${NC}"
                echo -e " Telegram Ch   : ${CYAN}t.me/zainuxbrand${NC}"
                echo -e " Help Line     : ${CYAN}03077716993${NC}"
                echo -e "${CYAN}----------------------------------------------------${NC}"
                echo -e "${BOLD}1) SSH WebSocket Dynamic Config:${NC}"
                echo -e "   Ports: 80 (HTTP), 443 (SSL), 22, 109"
                echo -e "   Payload: GET ${CUSTOM_PATH} HTTP/1.1[crlf]Host: ${cur_dom}[crlf]Upgrade: websocket[crlf][crlf]"
                echo -e "----------------------------------------------------"
                echo -e "${BOLD}2) Xray VMess WebSocket Branded Link:${NC}"
                echo -e "   vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"⚡ ZAINUXBRAND-VIP-${username}\",\"add\":\"${cur_dom}\",\"port\":\"80\",\"id\":\"${password}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\"}" | base64 -w 0)"
                echo -e "----------------------------------------------------"
                echo -e "${BOLD}3) Xray VLESS Premium Dynamic Link:${NC}"
                echo -e "   vless://${password}@${cur_dom}:4433?encryption=none&security=none&type=tcp#⚡+ZAINUXBRAND-VIP-${username}+[t.me/zainuxbrand]"
                echo -e "----------------------------------------------------"
                echo -e "${BOLD}4) SlowDNS (DNSTT) Parameters:${NC}"
                echo -e "   Nameserver Target (NS) : ${CYAN}${cur_dom}${NC}"
                echo -e "   Server Public Key (.pub): ${YELLOW}${pubkey}${NC}"
                echo -e "${GREEN}====================================================${NC}"
                press_any_key
                ;;
            2)
                read -rp "Username to delete: " username
                userdel -f "$username" 2>/dev/null
                rm -f "/etc/zainuxbrand/users/${username}.conf"
                echo -e "${GREEN}[SUCCESS] Account ${username} successfully terminated.${NC}"
                press_any_key
                ;;
            3) return ;;
        esac
    done
}

status_check() {
    clear
    local current_dom=$(get_domain)
    
    st_badge() {
        systemctl is-active "$1" &>/dev/null && echo -e "${GREEN}[ ACTIVE ]${NC}" || echo -e "${RED}[ INACTIVE ]${NC}"
    }

    echo -e "${CYAN}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}                     SYSTEM SERVICES STATUS MONITOR                 ${NC}"
    echo -e "${CYAN}====================================================================${NC}"
    echo -e " Target Domain : ${BOLD}${current_dom}${NC}\n"

    printf "   %-32s : %b\n" "Dropbear SSH Core Engine" "$(st_badge dropbear)"
    printf "   %-32s : %b\n" "Nginx Routing Engine" "$(st_badge nginx)"
    printf "   %-32s : %b\n" "Python Web-Proxy Tunnel Daemon" "$(st_badge ws-proxy)"
    printf "   %-32s : %b\n" "Xray Multi-Protocol Core" "$(st_badge xray)"
    printf "   %-32s : %b\n" "SlowDNS Server Engine (DNSTT)" "$(st_badge slowdns)"
    printf "   %-32s : %b\n" "Bandwidth Quota Controller" "$(st_badge autokill)"
    echo -e "${CYAN}====================================================================${NC}"
    press_any_key
}

uninstall_panel() {
    clear
    echo -e "${RED}${BOLD}====================================================================${NC}"
    echo -e "${RED}${BOLD}            WIPING AND DE-REGISTERING ALL CORE COMPONENTS          ${NC}"
    echo -e "${RED}${BOLD}====================================================================${NC}"
    read -rp "Type 'YES' to confirm complete system clean: " confirm

    if [[ "$confirm" == "YES" ]]; then
        systemctl stop dropbear nginx ws-proxy xray slowdns autokill &>/dev/null
        systemctl disable ws-proxy xray slowdns autokill &>/dev/null
        
        rm -rf /usr/local/etc/xray /etc/slowdns /etc/zainuxbrand /usr/local/bin/dnstt-server
        rm -f /etc/systemd/system/ws-proxy.service /etc/systemd/system/slowdns.service /etc/systemd/system/autokill.service
        
        iptables -t nat -F PREROUTING 2>/dev/null
        
        echo -e "${GREEN}[SUCCESS] Core system has been reset. Shell exiting...${NC}"
        exit 0
    fi
}

while true; do
    clear
    CURRENT_DOM=$(get_domain)
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN}       ${PANEL_NAME} (PREMIUM SELECTION)         ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e " Domain Target: ${YELLOW}${CURRENT_DOM}${NC}"
    echo -e " Protocols    : ${CYAN}SSH, WS-PROXY, VMESS, VLESS, TROJAN, SLOWDNS${NC}"
    echo -e "${CYAN}----------------------------------------------------${NC}"
    echo -e " 1) Auto Install System Components & Protocols"
    echo -e " 2) Add / Change Domain Name"
    echo -e " 3) Manage Accounts (Add/Delete Accounts)"
    echo -e " 4) Check Status & Operational Tunnels"
    echo -e " 5) Uninstall Panel (Remove All Components)"
    echo -e " 6) Exit Panel Shell"
    echo -e "${CYAN}====================================================${NC}"
    read -rp "Select Option [1-6]: " opt

    case $opt in
        1) install_all_components ;;
        2) add_domain_option ;;
        3) account_management_menu ;;
        4) status_check ;;
        5) uninstall_panel ;;
        6) exit 0 ;;
        *) echo "Invalid option"; sleep 1 ;;
    esac
done
