#!/bin/bash
#====================================================
#  ZAINI X BRAND PREMIUM VPN SCRIPT
#  Menu System (menu.sh) — Full Numbered Panel
#  Run with: menu
#====================================================

BASE_DIR="/etc/zainix-brand"
CERT_DIR="/etc/nginx/ssl"
DB_USERS="$BASE_DIR/users.db"
DOMAIN_FILE="$BASE_DIR/domain.txt"
UUID_FILE="$BASE_DIR/uuid.txt"
TRIAL_DIR="$BASE_DIR/trials"

mkdir -p "$BASE_DIR" "$TRIAL_DIR"

#------------- COLORS -------------
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

#------------- BANNER -------------
print_banner() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${R}        ZAINI X BRAND PREMIUM VPN SCRIPT${N}"
    echo -e "${Y}=====================================================${N}"
    echo -e "${C}   SSH • SSL • WS Dropbear • VLESS WS/TLS${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
}

#------------- STATUS CHECK -------------
check_status() {
    local STATUS=""
    for SVC in nginx ssh dropbear stunnel4 xray wstunnel-ssh; do
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
            STATUS="${STATUS}${G}✓${N} "
        else
            STATUS="${STATUS}${R}✗${N} "
        fi
    done
    echo -e "${W}Services: ${STATUS}(nginx ssh dropbear ssl xray ws-ssh)${N}"
}

#------------- GET INFO -------------
get_domain() {
    if [[ -f "$DOMAIN_FILE" ]]; then cat "$DOMAIN_FILE"; else echo "$(curl -s4 ifconfig.me)"; fi
}
get_ip() { curl -s4 ifconfig.me 2>/dev/null || echo "0.0.0.0"; }
get_uuid() { if [[ -f "$UUID_FILE" ]]; then cat "$UUID_FILE"; else uuidgen; fi; }

#====================================================
# OPTION 1 — CREATE SSH / SSL ACCOUNT
#====================================================
add_ssh_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [1] CREATE NEW SSH / SSL ACCOUNT${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    DOMAIN=$(get_domain)
    IP=$(get_ip)
    echo -e "${C}Host / Domain : ${W}$DOMAIN${N}"
    echo -e "${C}Server IP     : ${W}$IP${N}"
    echo ""

    read -p "Enter username        : " USER
    if [[ -z "$USER" ]]; then echo -e "${R}Cancelled.${N}"; sleep 1; return; fi
    if id "$USER" >/dev/null 2>&1; then
        echo -e "${R}User already exists!${N}"
        sleep 2
        return
    fi

    read -p "Enter password        : " PASS
if [[ -z "$PASS" ]]; then echo -e "${R}Password cannot be empty!${N}"; sleep 1; return; fi
    read -p "Validity (days)       : " DAYS
    read -p "IP Limit (0 = none)   : " IPLIMIT
    read -p "Bandwidth Limit (GB, 0 = unlimited): " GBLIMIT

    [[ -z "$DAYS" ]] && DAYS=30
    [[ -z "$IPLIMIT" ]] && IPLIMIT=0
    [[ -z "$GBLIMIT" ]] && GBLIMIT=0

    EXPIREDATE=$(date -d "+$DAYS days" +"%Y-%m-%d")

    useradd -m -s /bin/bash "$USER" 2>/dev/null
    echo "$USER:$PASS" | chpasswd
    usermod -e "$EXPIREDATE" "$USER"

    # Save user to DB (username|password|expired|iplimit|gblimit|created)
    echo "$USER|$PASS|$EXPIREDATE|$IPLIMIT|$GBLIMIT|$(date +%s)" >> "$DB_USERS"

    # Apply IP limit if set
    if [[ "$IPLIMIT" -gt 0 ]]; then
        apply_ip_limit "$USER" "$IPLIMIT"
    fi

    # Apply bandwidth limit if set (using iptables quota)
    if [[ "$GBLIMIT" -gt 0 ]]; then
        BYTES=$((GBLIMIT * 1024 * 1024 * 1024))
        iptables -I OUTPUT -m owner --uid-owner "$(id -u "$USER")" -m quota --quota "$BYTES" -j ACCEPT 2>/dev/null
        iptables -I OUTPUT -m owner --uid-owner "$(id -u "$USER")" -m quota --quota "$BYTES" -j DROP 2>/dev/null
    fi

    echo ""
    echo -e "${G}=====================================================${N}"
    echo -e "${G}        ACCOUNT CREATED SUCCESSFULLY${N}"
    echo -e "${G}=====================================================${N}"
    echo ""
    echo -e "${W}Host / Domain : ${C}$DOMAIN${N}"
    echo -e "${W}Server IP     : ${C}$IP${N}"
    echo -e "${W}Username      : ${C}$USER${N}"
    echo -e "${W}Password      : ${C}$PASS${N}"
    echo -e "${W}Expired Date  : ${C}$EXPIREDATE${N}"
    echo -e "${W}IP Limit      : ${C}$IPLIMIT${N}"
    echo -e "${W}Bandwidth (GB): ${C}$GBLIMIT${N}"
    echo ""
    echo -e "${Y}--- SSH Direct (Port 22) ---${N}"
    echo -e "${C}$USER@$DOMAIN:22${N}"
    echo ""
    echo -e "${Y}--- SSH SSL via Stunnel (Port 443) ---${N}"
    echo -e "${C}$USER@$DOMAIN:443${N}"
    echo ""
    echo -e "${Y}--- SSH Dropbear (Port 109) ---${N}"
    echo -e "${C}$USER@$DOMAIN:109${N}"
    echo ""
    echo -e "${Y}--- SSH WebSocket (Port 80/443 path /ws-ssh) ---${N}"
    echo -e "${C}$USER@$DOMAIN:80@SSL${N}"
    echo ""
    echo -e "${Y}--- DarkTunnel Payload ---${N}"
    echo -e "${C}GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf]Connection: <div><span style=\"color: #0000ff\"> ✨❤@ZAINU X BRAND ➡| 03077716993🇵🇰| ✈ •🪶(BOY) 🇸 🅦</span></div> Upgrade[crlf]User-Agent: [ua][crlf][crlf]${N}"
    echo ""
    echo -e "${G}=====================================================${N}"
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 2 — CREATE VLESS ACCOUNT
#====================================================
add_vless_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [2] CREATE NEW VLESS ACCOUNT${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    DOMAIN=$(get_domain)
    IP=$(get_ip)
    UUID=$(uuidgen)
    echo -e "${C}Host / Domain : ${W}$DOMAIN${N}"
    echo -e "${C}Server IP     : ${W}$IP${N}"
    echo ""

    read -p "Enter username / label : " USER
    read -p "Validity (days)        : " DAYS
    [[ -z "$DAYS" ]] && DAYS=30
    EXPIREDATE=$(date -d "+$DAYS days" +"%Y-%m-%d")

    # Inject new client into xray config
    if [[ -f /usr/local/etc/xray/config.json ]]; then
        cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
        python3 - <<PYEOF
import json
with open("/usr/local/etc/xray/config.json","r") as f:
    cfg = json.load(f)
new_client = {"id": "${UUID}", "level": 0, "email": "${USER}", "limit": "${EXPIREDATE}"}
for inbound in cfg.get("inbounds", []):
    if inbound.get("protocol") == "vless":
        clients = inbound["settings"]["clients"]
        # Remove expired clients
        import datetime
        today = datetime.date.today().isoformat()
        clients[:] = [c for c in clients if c.get("limit","") >= today or c.get("email","").startswith("default")]
        clients.append(new_client)
with open("/usr/local/etc/xray/config.json","w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
        systemctl restart xray 2>/dev/null
    fi

    # Save to DB
    echo "vless-${USER}|${UUID}|${EXPIREDATE}|0|0|$(date +%s)" >> "$DB_USERS"

    echo ""
    echo -e "${G}=====================================================${N}"
    echo -e "${G}        VLESS ACCOUNT CREATED${N}"
    echo -e "${G}=====================================================${N}"
    echo ""
    echo -e "${W}Username   : ${C}$USER${N}"
    echo -e "${W}UUID       : ${C}$UUID${N}"
    echo -e "${W}Host       : ${C}$DOMAIN${N}"
    echo -e "${W}IP         : ${C}$IP${N}"
    echo -e "${W}Expired    : ${C}$EXPIREDATE${N}"
    echo ""
    echo -e "${Y}--- VLESS WS non-TLS (Port 80) ---${N}"
    echo -e "${C}vless://${UUID}@${DOMAIN}:80?type=ws&path=/vless-ws&security=none#${USER}-VLESS-nTLS${N}"
    echo ""
    echo -e "${Y}--- VLESS WS TLS (Port 443) ---${N}"
    echo -e "${C}vless://${UUID}@${DOMAIN}:443?type=ws&security=tls&path=/vless-ws&sni=${DOMAIN}#${USER}-VLESS-TLS${N}"
    echo ""
    echo -e "${G}=====================================================${N}"
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 3 — CREATE TRIAL ACCOUNT (24h)
#====================================================
add_trial_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [3] CREATE TRIAL ACCOUNT (24 HOURS)${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    DOMAIN=$(get_domain)
    IP=$(get_ip)

    TRIAL_USER="trial-$(date +%s | tail -c 5)"
    TRIAL_PASS=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 8)
    EXPIREDATE=$(date -d "+1 days" +"%Y-%m-%d")

    useradd -m -s /bin/bash "$TRIAL_USER" 2>/dev/null
    echo "$TRIAL_USER:$TRIAL_PASS" | chpasswd
    usermod -e "$EXPIREDATE" "$TRIAL_USER"

    echo "$TRIAL_USER|$TRIAL_PASS|$EXPIREDATE|1|1|$(date +%s)" >> "$DB_USERS"
    echo "$TRIAL_USER" >> "$TRIAL_DIR/trials.txt"

    echo ""
    echo -e "${G}=====================================================${N}"
    echo -e "${G}        TRIAL ACCOUNT CREATED (24h)${N}"
    echo -e "${G}=====================================================${N}"
    echo ""
    echo -e "${W}Host / Domain : ${C}$DOMAIN${N}"
    echo -e "${W}Server IP     : ${C}$IP${N}"
    echo -e "${W}Username      : ${C}$TRIAL_USER${N}"
    echo -e "${W}Password      : ${C}$TRIAL_PASS${N}"
    echo -e "${W}Expired Date  : ${C}$EXPIREDATE (24 hours)${N}"
    echo -e "${W}IP Limit      : ${C}1${N}"
    echo -e "${W}Bandwidth (GB): ${C}1${N}"
    echo ""
    echo -e "${Y}SSH SSL: ${C}$TRIAL_USER@$DOMAIN:443${N}"
    echo ""
    echo -e "${G}=====================================================${N}"
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 4 — DELETE USER
#====================================================
delete_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${R}        [4] DELETE USER${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    list_users_short
    echo ""
    read -p "Enter username to delete: " USER
    if [[ -z "$USER" ]]; then return; fi

    if id "$USER" >/dev/null 2>&1; then
        userdel -r "$USER" 2>/dev/null
        echo -e "${G}User $USER deleted from system.${N}"
    fi

    # Remove from xray config if present
    if [[ -f /usr/local/etc/xray/config.json ]]; then
        python3 - <<PYEOF
import json
with open("/usr/local/etc/xray/config.json","r") as f:
    cfg = json.load(f)
for inbound in cfg.get("inbounds", []):
    if inbound.get("protocol") == "vless":
        inbound["settings"]["clients"] = [c for c in inbound["settings"]["clients"] if c.get("email") != "${USER}"]
with open("/usr/local/etc/xray/config.json","w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
        systemctl restart xray 2>/dev/null
    fi

    # Remove from db
    [[ -f "$DB_USERS" ]] && sed -i "/^${USER}|/d" "$DB_USERS"
    echo -e "${G}User $USER fully removed.${N}"
    sleep 2
}

#====================================================
# OPTION 5 — EXTEND USER
#====================================================
extend_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [5] EXTEND USER VALIDITY${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    list_users_short
    echo ""
    read -p "Enter username         : " USER
    read -p "Add days (e.g. 7, 30)  : " ADD_DAYS
    if [[ -z "$USER" || -z "$ADD_DAYS" ]]; then return; fi
    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${R}User not found.${N}"
        sleep 2
        return
    fi

    CURRENT_EXP=$(chage -l "$USER" | grep "Account expires" | awk -F': ' '{print $2}' | tr -d ' ')
    if [[ -z "$CURRENT_EXP" || "$CURRENT_EXP" == "never" ]]; then
        NEW_EXP=$(date -d "+$ADD_DAYS days" +"%Y-%m-%d")
    else
        NEW_EXP=$(date -d "$CURRENT_EXP +$ADD_DAYS days" +"%Y-%m-%d")
    fi
    usermod -e "$NEW_EXP" "$USER"

    # Update DB
    if [[ -f "$DB_USERS" ]]; then
        sed -i "s|^${USER}|${USER}|" "$DB_USERS"
        # Update expiry field
        awk -F'|' -v u="$USER" -v e="$NEW_EXP" 'BEGIN{OFS="|"} $1==u{$3=e} 1' "$DB_USERS" > "$DB_USERS.tmp" && mv "$DB_USERS.tmp" "$DB_USERS"
    fi

    echo -e "${G}User $USER extended to $NEW_EXP${N}"
    sleep 2
}

#====================================================
# OPTION 6 — LOCK USER
#====================================================
lock_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${R}        [6] LOCK USER${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    list_users_short
    echo ""
    read -p "Enter username to lock: " USER
    if [[ -z "$USER" ]]; then return; fi
    if id "$USER" >/dev/null 2>&1; then
        passwd -l "$USER" 2>/dev/null
        usermod -s /usr/sbin/nologin "$USER" 2>/dev/null
        echo -e "${G}User $USER locked.${N}"
    else
        echo -e "${R}User not found.${N}"
    fi
    sleep 2
}

#====================================================
# OPTION 7 — UNLOCK USER
#====================================================
unlock_user() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [7] UNLOCK USER${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    list_users_short
    echo ""
    read -p "Enter username to unlock: " USER
    if [[ -z "$USER" ]]; then return; fi
    if id "$USER" >/dev/null 2>&1; then
        passwd -u "$USER" 2>/dev/null
        usermod -s /bin/bash "$USER" 2>/dev/null
        echo -e "${G}User $USER unlocked.${N}"
    else
        echo -e "${R}User not found.${N}"
    fi
    sleep 2
}

#====================================================
# OPTION 8 — LIST USERS
#====================================================
list_users() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [8] ALL USERS${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    list_users_short
    echo ""
    read -p "Press Enter to continue..."
}

list_users_short() {
    echo -e "${C}----------------------------------------------------------------${N}"
    printf "${W}%-18s %-12s %-12s %-12s %-12s${N}\n" "USERNAME" "EXPIRED" "IP-LIMIT" "GB-LIMIT" "STATUS"
    echo -e "${C}----------------------------------------------------------------${N}"
    if [[ -f "$DB_USERS" ]]; then
        while IFS='|' read -r U P EXP IPL GBL CREATED; do
            if id "$U" >/dev/null 2>&1; then
                STATUS="${G}active${N}"
            else
                STATUS="${R}deleted${N}"
            fi
            printf "${G}%-18s %-12s %-12s %-12s %-12s${N}\n" "$U" "$EXP" "$IPL" "$GBL" "$STATUS"
        done < "$DB_USERS"
    else
        echo -e "${R}No users found. Create one first.${N}"
    fi
    echo -e "${C}----------------------------------------------------------------${N}"
}

#====================================================
# OPTION 9 — SHOW CONNECTION INFO / PAYLOADS
#====================================================
show_payload() {
    clear
    DOMAIN=$(get_domain)
    IP=$(get_ip)
    UUID=$(get_uuid)
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        CONNECTION INFO & PAYLOADS${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    echo -e "${W}Host / Domain : ${C}$DOMAIN${N}"
    echo -e "${W}Server IP     : ${C}$IP${N}"
    echo ""
    echo -e "${Y}--- VLESS WS TLS (Port 8443) ---${N}"
    echo -e "${C}vless://${UUID}@${DOMAIN}:8443?type=ws&security=tls&path=/vless-ws&sni=${DOMAIN}#ZAINIX-VLESS-TLS${N}"
    echo ""
    echo -e "${Y}--- VLESS WS non-TLS (Port 80) ---${N}"
    echo -e "${C}vless://${UUID}@${DOMAIN}:80?type=ws&security=none&path=/vless-ws#ZAINIX-VLESS-nTLS${N}"
    echo ""
    echo -e "${Y}--- DarkTunnel SSH SSL (Port 443) ---${N}"
    echo -e "${C}Target: ${DOMAIN}:443@username:password${N}"
    echo -e "${C}Proxy : go.onic.pk:443${N}"
    echo -e "${C}SNI   : ${DOMAIN}${N}"
    echo ""
    echo -e "${C}Payload:${N}"
    echo -e "${W}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]${N}"
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 10 — SSL CERTIFICATE INFO
#====================================================
cert_info() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [10] SSL CERTIFICATE INFO${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    if [[ -f "$CERT_DIR/cert.crt" ]]; then
        echo -e "${W}Certificate : ${C}$CERT_DIR/cert.crt${N}"
        echo -e "${W}Private Key : ${C}$CERT_DIR/private.key${N}"
        echo ""
        echo -e "${W}Certificate Details:${N}"
        openssl x509 -in "$CERT_DIR/cert.crt" -noout -subject -dates -issuer 2>/dev/null
        echo ""
        echo -e "${W}SHA-256 Fingerprint:${N}"
        openssl x509 -in "$CERT_DIR/cert.crt" -noout -fingerprint -sha256 2>/dev/null
    else
        echo -e "${R}No certificate found! Run install first.${N}"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 11 — SERVICE STATUS
#====================================================
service_status() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [11] SERVICE STATUS${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    echo -e "${W}Services:${N}"
    for SVC in nginx ssh dropbear stunnel4 xray wstunnel-ssh; do
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
            echo -e "  ${G}✓ $SVC${N} — ${G}running${N}"
        else
            echo -e "  ${R}✗ $SVC${N} — ${R}stopped${N}"
        fi
    done
    echo ""
    echo -e "${W}Listening Ports:${N}"
    ss -tlnp 2>/dev/null | grep -E ':(22|80|109|110|443|8881|8882|10000)' | awk '{print $4,$6}' | sort -u
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 12 — RESTART SERVICES
#====================================================
restart_services() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [12] RESTART ALL SERVICES${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    for SVC in nginx ssh dropbear stunnel4 xray wstunnel-ssh; do
        systemctl restart "$SVC" 2>/dev/null
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
            echo -e "  ${G}✓ $SVC restarted${N}"
        else
            echo -e "  ${R}✗ $SVC failed${N}"
        fi
    done
    echo ""
    sleep 2
}

#====================================================
# OPTION 13 — BANDWIDTH USAGE
#====================================================
bandwidth_usage() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [13] BANDWIDTH USAGE${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    if ! command -v vnstat &>/dev/null; then
        echo -e "${Y}Installing vnstat for bandwidth monitoring...${N}"
        apt install -y vnstat 2>/dev/null
        systemctl enable vnstat 2>/dev/null
        systemctl start vnstat 2>/dev/null
    fi
    echo -e "${W}Network Interface Traffic:${N}"
    echo ""
    vnstat 2>/dev/null || echo -e "${R}vnstat not available yet.${N}"
    echo ""
    echo -e "${W}Per-user bandwidth (iptables quota):${N}"
    iptables -L OUTPUT -n -v 2>/dev/null | grep -E "owner|quota" | head -20
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 14 — SYSTEM INFO
#====================================================
system_info() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [14] SYSTEM INFO${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    DOMAIN=$(get_domain)
    IP=$(get_ip)
    echo -e "${W}Hostname       : ${C}$(hostname)${N}"
    echo -e "${W}Server IP      : ${C}$IP${N}"
    echo -e "${W}Domain         : ${C}$DOMAIN${N}"
    echo -e "${W}OS             : ${C}$(. /etc/os-release && echo "$PRETTY_NAME")${N}"
    echo -e "${W}Kernel         : ${C}$(uname -r)${N}"
    echo -e "${W}Uptime         : ${C}$(uptime -p)${N}"
    echo -e "${W}CPU            : ${C}$(nproc) cores${N}"
    echo -e "${W}RAM            : ${C}$(free -h | awk '/^Mem:/ {print $2}') total${N}"
    echo -e "${W}Disk           : ${C}$(df -h / | awk 'NR==2 {print $2}') total${N}"
    echo ""
    echo -e "${W}Online Users   : ${C}$(who | wc -l)${N}"
    echo -e "${W}Total Accounts : ${C}$([[ -f $DB_USERS ]] && wc -l < $DB_USERS || echo 0)${N}"
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 15 — PREVIEW SERVER BANNER
#====================================================
banner_preview() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [15] SERVER BANNER PREVIEW${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    echo -e "${G}=====================================================${N}"
    echo -e "${G}      WELCOME TO ZAINUXBRAND VIP VPN${N}"
    echo -e "${R}   - NO TORRENT / NO MULTILOGIN -${N}"
    echo -e "${G}=====================================================${N}"
    echo ""
    echo -e "${W}This banner shows when user connects via SSH/SSL.${N}"
    echo ""
    read -p "Press Enter to continue..."
}

#====================================================
# OPTION 16 — UPDATE SCRIPT
#====================================================
update_script() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${G}        [16] UPDATE SCRIPT${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    REPO_RAW="https://raw.githubusercontent.com/zainiking8/vps-panel/main"
    echo -e "${Y}Fetching latest menu.sh from GitHub...${N}"
    curl -fsSL "$REPO_RAW/menu.sh" -o /usr/local/bin/menu 2>/dev/null
    chmod +x /usr/local/bin/menu
    echo -e "${G}Menu updated. Restarting...${N}"
    sleep 2
    exec /usr/local/bin/menu
}

#====================================================
# OPTION 17 — UNINSTALL
#====================================================
uninstall_all() {
    clear
    echo -e "${Y}=====================================================${N}"
    echo -e "${R}        [17] UNINSTALL (FULL CLEAN)${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    read -p "Are you sure? Type 'yes' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "${Y}Cancelled.${N}"
        sleep 2
        return
    fi
    bash /usr/local/bin/zainix-uninstall
}

#====================================================
# HELPER — APPLY IP LIMIT
#====================================================
apply_ip_limit() {
    local USER="$1"
    local LIMIT="$2"
    # Basic IP limit via PAM limits (real multi-IP limit needs extra tools)
    # For demo: limit via pam_limits
    echo "session required pam_limits.so" >> /etc/pam.d/sshd 2>/dev/null
    echo "$USER hard maxlogins $LIMIT" >> /etc/security/limits.conf 2>/dev/null
}

#====================================================
# MAIN LOOP — NUMBERED MENU
#====================================================
while true; do
    print_banner
    check_status
    echo ""
    echo -e "${Y}=================== USER ACCOUNTS ===================${N}"
    echo -e "${G} [1]${W}  Create SSH / SSL Account${N}"
    echo -e "${G} [2]${W}  Create VLESS Account${N}"
    echo -e "${G} [3]${W}  Create Trial Account (24h)${N}"
    echo -e "${R} [4]${W}  Delete User${N}"
    echo -e "${Y} [5]${W}  Extend User Validity${N}"
    echo -e "${R} [6]${W}  Lock User${N}"
    echo -e "${G} [7]${W}  Unlock User${N}"
    echo -e "${C} [8]${W}  List All Users${N}"
    echo -e "${Y}=================== INFO & TOOLS ====================${N}"
    echo -e "${C} [9]${W}  Show Connection Info / Payloads${N}"
    echo -e "${C} [10]${W} SSL Certificate Info${N}"
    echo -e "${C} [11]${W} Service Status${N}"
    echo -e "${C} [12]${W} Restart Services${N}"
    echo -e "${C} [13]${W} Bandwidth Usage${N}"
    echo -e "${C} [14]${W} System Info${N}"
    echo -e "${C} [15]${W} Preview Server Banner${N}"
    echo -e "${C} [16]${W} Update Script${N}"
    echo -e "${Y}=====================================================${N}"
    echo -e "${R} [17]${W} Uninstall (full clean)${N}"
    echo -e "${R} [0]${W}  Exit${N}"
    echo -e "${Y}=====================================================${N}"
    echo ""
    read -p "Select option [0-17]: " OPT
    case $OPT in
        1)  add_ssh_user ;;
        2)  add_vless_user ;;
        3)  add_trial_user ;;
        4)  delete_user ;;
        5)  extend_user ;;
        6)  lock_user ;;
        7)  unlock_user ;;
        8)  list_users ;;
        9)  show_payload ;;
        10) cert_info ;;
        11) service_status ;;
        12) restart_services ;;
        13) bandwidth_usage ;;
        14) system_info ;;
        15) banner_preview ;;
        16) update_script ;;
        17) uninstall_all ;;
        0)  echo -e "${G}Bye! — ZAINI X BRAND${N}"; exit 0 ;;
        *)  echo -e "${R}Invalid option.${N}"; sleep 1 ;;
    esac
done