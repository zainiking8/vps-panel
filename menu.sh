#!/usr/bin/env bash
# ============================================================
# ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
# Ubuntu 20.04 / 22.04 / 24.04
# ============================================================

set -Eeuo pipefail

SCRIPT_NAME="ZAINUXBRAND 😎 PREMIUM VPN SCRIPT"
SCRIPT_VERSION="2.0.0"
CONFIG_DIR="/etc/zainuxbrand"
BACKUP_DIR="/root/zainuxbrand-backups"
LOG_FILE="/var/log/zainuxbrand.log"
SELF="/usr/local/bin/menu"

# Change this to your GitHub RAW URL before publishing.
UPDATE_URL="${UPDATE_URL:-https://raw.githubusercontent.com/YOUR-GITHUB-USER/YOUR-REPO/main/menu.sh}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

msg(){ echo -e "${CYAN}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERROR]${NC} $*"; }

trap 'err "Command failed at line $LINENO"; exit 1' ERR

require_root(){
    if [[ "${EUID}" -ne 0 ]]; then
        err "Please run this script as root."
        exit 1
    fi
}

check_ubuntu(){
    [[ -f /etc/os-release ]] || { err "Cannot detect operating system."; exit 1; }
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        err "This panel is designed for Ubuntu."
        err "Detected: ${PRETTY_NAME:-unknown}"
        exit 1
    fi
    case "${VERSION_ID:-}" in
        20.04|22.04|24.04) ok "Supported Ubuntu: ${PRETTY_NAME}" ;;
        *) warn "Ubuntu ${VERSION_ID:-unknown} detected; supported: 20.04 / 22.04 / 24.04" ;;
    esac
}

init_state(){
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    touch "$CONFIG_DIR/installed-packages"
}

log_cmd(){
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

record_package(){
    local p="$1"
    grep -qxF "$p" "$CONFIG_DIR/installed-packages" 2>/dev/null || echo "$p" >> "$CONFIG_DIR/installed-packages"
}

install_packages(){
    require_root
    export DEBIAN_FRONTEND=noninteractive
    init_state
    msg "Updating package lists..."
    apt-get update -y
    msg "Installing required packages..."
    local packages=(curl wget ca-certificates gnupg unzip jq openssl cron socat nginx certbot python3-certbot-nginx ufw dnsutils)
    local p
    for p in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed"; then
            echo "$p" >> "$CONFIG_DIR/installed-packages.pending"
        fi
    done
    apt-get install -y "${packages[@]}"
    if [[ -f "$CONFIG_DIR/installed-packages.pending" ]]; then
        sort -u "$CONFIG_DIR/installed-packages.pending" >> "$CONFIG_DIR/installed-packages"
        sort -u -o "$CONFIG_DIR/installed-packages" "$CONFIG_DIR/installed-packages"
        rm -f "$CONFIG_DIR/installed-packages.pending"
    fi
    ok "Required packages installed."
}

system_update(){
    require_root
    export DEBIAN_FRONTEND=noninteractive
    msg "Running system update..."
    apt-get update -y
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get autoclean -y
    ok "System update completed."
}

get_server_ip(){
    SERVER_IP="$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
    [[ -n "$SERVER_IP" ]] || SERVER_IP="unknown"
    echo "$SERVER_IP" > "$CONFIG_DIR/server_ip"
    msg "Server IPv4: $SERVER_IP"
}

domain_setup(){
    init_state
    echo
    read -rp "Enter your SSL/Xray domain: " DOMAIN
    [[ -n "$DOMAIN" ]] || { err "Domain cannot be empty."; return 1; }
    DOMAIN="${DOMAIN,,}"
    [[ "$DOMAIN" != *" "* ]] || { err "Invalid domain."; return 1; }
    echo "$DOMAIN" > "$CONFIG_DIR/domain"
    get_server_ip
    msg "Checking DNS for $DOMAIN ..."
    RESOLVED_IP="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
    if [[ -n "$RESOLVED_IP" ]]; then
        msg "DNS resolves to: $RESOLVED_IP"
        [[ "$SERVER_IP" == "unknown" || "$RESOLVED_IP" == "$SERVER_IP" ]] \
            && ok "DNS appears correctly configured." \
            || warn "Domain does not currently resolve to this VPS."
    else
        warn "Domain could not be resolved. Create an A record pointing to this VPS."
    fi
}

load_domain(){
    if [[ -f "$CONFIG_DIR/domain" ]]; then
        DOMAIN="$(cat "$CONFIG_DIR/domain")"
    else
        domain_setup
    fi
}

setup_nginx(){
    require_root
    load_domain
    msg "Configuring Nginx..."
    cat > /etc/nginx/sites-available/zainuxbrand.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location / {
        return 200 "ZAINUXBRAND 😎 PREMIUM VPN SCRIPT\n";
        add_header Content-Type text/plain;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/zainuxbrand.conf /etc/nginx/sites-enabled/zainuxbrand.conf
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl enable nginx
    systemctl restart nginx
    ok "Nginx configured."
}

setup_ssl(){
    require_root
    load_domain
    msg "Requesting/renewing Let's Encrypt certificate..."
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
        --register-unsafely-without-email --redirect; then
        ok "SSL certificate installed for $DOMAIN"
    else
        warn "Certificate request failed. Check DNS and port 80."
        return 1
    fi
    systemctl enable certbot.timer 2>/dev/null || true
    systemctl start certbot.timer 2>/dev/null || true
}

install_xray(){
    require_root
    install_packages >/dev/null
    if command -v xray >/dev/null 2>&1; then
        ok "Xray is already installed."
        return 0
    fi
    msg "Installing Xray..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    command -v xray >/dev/null 2>&1 || { err "Xray installation failed."; return 1; }
    ok "Xray installed successfully."
}

configure_xray(){
    require_root
    install_xray
    load_domain
    mkdir -p /usr/local/etc/xray
    UUID="$(xray uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
    cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {"address": "127.0.0.1"}
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ]
}
EOF
    printf '%s\n' "$UUID" > "$CONFIG_DIR/xray-uuid"
    printf '%s\n' "$DOMAIN" > "$CONFIG_DIR/xray-domain"
    systemctl enable xray >/dev/null 2>&1 || true
    systemctl restart xray 2>/dev/null || true
    ok "Xray installed and base configuration created."
    msg "UUID: $UUID"
    warn "A public VLESS/WS/TLS inbound is not created by this base configuration."
}

create_banner(){
    require_root
    cat > /etc/motd <<EOF
======================================================
       $SCRIPT_NAME
======================================================
       Authorized server access only.
======================================================
EOF
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/zainuxbrand-banner.conf <<'EOF'
Banner /etc/ssh/zainuxbrand-banner
EOF
    cat > /etc/ssh/zainuxbrand-banner <<EOF

======================================================
       $SCRIPT_NAME
======================================================
       Authorized server access only.
======================================================

EOF
    if sshd -t 2>/dev/null; then
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
        ok "SSH branding enabled."
    else
        warn "SSH configuration test failed; banner not activated."
    fi
}

firewall_setup(){
    require_root
    msg "Configuring basic firewall..."
    ufw allow OpenSSH >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    ufw allow 53/tcp >/dev/null 2>&1 || true
    ufw allow 53/udp >/dev/null 2>&1 || true
    echo "y" | ufw enable >/dev/null 2>&1 || true
    ok "Firewall configured."
}

create_user(){
    require_root
    echo
    read -rp "Username: " USERNAME
    [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { err "Invalid Linux username."; return 1; }
    if id "$USERNAME" >/dev/null 2>&1; then
        warn "User already exists."
        return 0
    fi
    adduser --disabled-password --gecos "" "$USERNAME"
    passwd "$USERNAME"
    read -rp "IP limit (number, default 1): " IP_LIMIT
    IP_LIMIT="${IP_LIMIT:-1}"
    read -rp "GB limit (0 = unlimited): " GB_LIMIT
    GB_LIMIT="${GB_LIMIT:-0}"
    read -rp "Expiry days (0 = never): " EXPIRY_DAYS
    EXPIRY_DAYS="${EXPIRY_DAYS:-0}"
    EXPIRY_TS=0
    if [[ "$EXPIRY_DAYS" =~ ^[0-9]+$ && "$EXPIRY_DAYS" -gt 0 ]]; then
        EXPIRY_TS=$(( $(date +%s) + EXPIRY_DAYS*86400 ))
    fi
    mkdir -p "$CONFIG_DIR/users"
    cat > "$CONFIG_DIR/users/$USERNAME" <<EOF
USERNAME=$USERNAME
IP_LIMIT=$IP_LIMIT
GB_LIMIT=$GB_LIMIT
EXPIRY_TS=$EXPIRY_TS
CREATED_TS=$(date +%s)
EOF
    ok "User $USERNAME created."
    echo "IP limit : $IP_LIMIT"
    echo "GB limit : $GB_LIMIT"
    [[ "$EXPIRY_TS" -eq 0 ]] && echo "Expiry   : Never" || echo "Expiry   : $(date -d "@$EXPIRY_TS" '+%Y-%m-%d %H:%M')"
}

delete_user(){
    require_root
    read -rp "Username to delete: " USERNAME
    [[ "$USERNAME" != "root" ]] || { err "Root user cannot be deleted."; return 1; }
    if id "$USERNAME" >/dev/null 2>&1; then
        userdel -r "$USERNAME" 2>/dev/null || userdel "$USERNAME"
        rm -f "$CONFIG_DIR/users/$USERNAME"
        ok "User $USERNAME deleted."
    else
        warn "User does not exist."
    fi
}

list_users(){
    echo
    echo "================ SSH USERS ================"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        echo " - $user"
    done
    echo "============================================"
}

show_user_details(){
    read -rp "Username: " USERNAME
    if [[ -f "$CONFIG_DIR/users/$USERNAME" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_DIR/users/$USERNAME"
        echo "Username : $USERNAME"
        echo "IP limit : ${IP_LIMIT:-1}"
        echo "GB limit : ${GB_LIMIT:-0}"
        if [[ "${EXPIRY_TS:-0}" -eq 0 ]]; then
            echo "Expiry   : Never"
        else
            echo "Expiry   : $(date -d "@$EXPIRY_TS" '+%Y-%m-%d %H:%M')"
        fi
    else
        warn "No panel record found for this user."
    fi
}

lock_expired_users(){
    require_root
    local now username expiry
    now="$(date +%s)"
    mkdir -p "$CONFIG_DIR/users"
    shopt -s nullglob
    for f in "$CONFIG_DIR/users/"*; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        source "$f"
        username="${USERNAME:-}"
        expiry="${EXPIRY_TS:-0}"
        if [[ -n "$username" && "$expiry" =~ ^[0-9]+$ && "$expiry" -gt 0 && "$expiry" -le "$now" ]]; then
            passwd -l "$username" >/dev/null 2>&1 || true
            log_cmd "Locked expired user: $username"
        fi
    done
    ok "Expired-user check completed."
}

install_expiry_timer(){
    require_root
    cat > /etc/systemd/system/zainuxbrand-expiry.service <<'EOF'
[Unit]
Description=ZAINUXBRAND expired SSH user checker

[Service]
Type=oneshot
ExecStart=/usr/local/bin/menu --expire-check
EOF
    cat > /etc/systemd/system/zainuxbrand-expiry.timer <<'EOF'
[Unit]
Description=Run ZAINUXBRAND expiry checker hourly

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Unit=zainuxbrand-expiry.service

[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable --now zainuxbrand-expiry.timer
    ok "Automatic expiry timer enabled."
}

backup_configs(){
    require_root
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR/$stamp"
    cp -a "$CONFIG_DIR" "$BACKUP_DIR/$stamp/" 2>/dev/null || true
    cp -a /etc/nginx "$BACKUP_DIR/$stamp/" 2>/dev/null || true
    cp -a /usr/local/etc/xray "$BACKUP_DIR/$stamp/" 2>/dev/null || true
    ok "Backup created: $BACKUP_DIR/$stamp"
}

show_info(){
    load_domain
    get_server_ip >/dev/null
    echo
    echo "======================================================"
    echo "              SERVER INFORMATION"
    echo "======================================================"
    echo "Brand       : $SCRIPT_NAME"
    echo "Version     : $SCRIPT_VERSION"
    echo "Domain      : ${DOMAIN:-not configured}"
    echo "Server IP   : ${SERVER_IP:-unknown}"
    echo "OS          : $(. /etc/os-release; echo "$PRETTY_NAME")"
    echo "Hostname    : $(hostname)"
    echo "======================================================"
}

service_status(){
    echo
    for svc in nginx xray zainuxbrand-expiry.timer; do
        if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
            echo "----- $svc -----"
            systemctl --no-pager --full status "$svc" 2>/dev/null | head -n 18 || true
        fi
    done
}

restart_services(){
    require_root
    systemctl restart nginx 2>/dev/null || true
    systemctl restart xray 2>/dev/null || true
    ok "Service restart commands completed."
}

self_update(){
    require_root
    local url="${1:-$UPDATE_URL}"
    if [[ "$url" == *"YOUR-GITHUB-USER"* || "$url" == *"YOUR-REPO"* ]]; then
        err "Set UPDATE_URL to your real GitHub RAW menu.sh URL first."
        echo "Example:"
        echo "https://raw.githubusercontent.com/USERNAME/REPOSITORY/main/menu.sh"
        return 1
    fi

    local tmp
    tmp="$(mktemp)"
    msg "Downloading latest menu.sh..."
    curl -fL --connect-timeout 15 --max-time 120 "$url" -o "$tmp"
    [[ -s "$tmp" ]] || { rm -f "$tmp"; err "Downloaded file is empty."; return 1; }
    head -n 1 "$tmp" | grep -qE '^#!/.*(bash|env bash)' || {
        rm -f "$tmp"; err "Downloaded file does not look like a bash script."; return 1;
    }
    bash -n "$tmp" || { rm -f "$tmp"; err "GitHub script has a syntax error. Existing panel was not changed."; return 1; }
    install -m 755 "$tmp" "$SELF"
    rm -f "$tmp"
    ok "Panel updated successfully."
    exec "$SELF"
}

install_from_github(){
    require_root
    local url="$1"
    local tmp
    tmp="$(mktemp)"
    msg "Installing panel from GitHub..."
    curl -fL --connect-timeout 15 --max-time 120 "$url" -o "$tmp"
    [[ -s "$tmp" ]] || { rm -f "$tmp"; err "Downloaded file is empty."; return 1; }
    bash -n "$tmp" || { rm -f "$tmp"; err "GitHub menu.sh has a syntax error."; return 1; }
    install -m 755 "$tmp" "$SELF"
    rm -f "$tmp"
    ok "Panel installed at $SELF"
    exec "$SELF"
}

uninstall_panel(){
    require_root
    echo
    echo "======================================================"
    echo "              PANEL UNINSTALL / CLEANUP"
    echo "======================================================"
    echo "This removes ZAINUXBRAND panel files and services."
    echo "It does NOT factory-reset the VPS or erase Ubuntu itself."
    echo
    read -rp 'Type DELETE to continue: ' CONFIRM
    [[ "$CONFIRM" == "DELETE" ]] || { warn "Cancelled."; return 0; }

    systemctl disable --now zainuxbrand-expiry.timer 2>/dev/null || true
    systemctl disable --now zainuxbrand-expiry.service 2>/dev/null || true
    rm -f /etc/systemd/system/zainuxbrand-expiry.service
    rm -f /etc/systemd/system/zainuxbrand-expiry.timer
    systemctl daemon-reload

    rm -f /etc/nginx/sites-enabled/zainuxbrand.conf
    rm -f /etc/nginx/sites-available/zainuxbrand.conf
    rm -f /etc/ssh/sshd_config.d/zainuxbrand-banner.conf
    rm -f /etc/ssh/zainuxbrand-banner
    rm -f /etc/motd

    # Read the package list BEFORE removing the panel state directory.
    local package_file="/tmp/zainuxbrand-installed-packages.$$"
    if [[ -f "$CONFIG_DIR/installed-packages" ]]; then
        cp "$CONFIG_DIR/installed-packages" "$package_file"
    fi

    rm -rf "$CONFIG_DIR"
    rm -rf "$BACKUP_DIR"

    # Remove only packages that this panel itself installed.
    if [[ -s "$package_file" ]]; then
        xargs -r apt-get purge -y < "$package_file" || true
        rm -f "$package_file"
        apt-get autoremove -y || true
        apt-get autoclean -y || true
    fi

    # Common Xray files created by the panel.
    rm -rf /usr/local/etc/xray
    rm -f /usr/local/bin/xray /usr/local/bin/xrayr
    rm -f "$SELF"

    systemctl daemon-reload
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

    echo
    ok "ZAINUXBRAND panel cleanup completed."
    warn "The VPS is not guaranteed to be byte-for-byte factory fresh."
    warn "Any packages/configurations that existed before this panel are intentionally preserved."
    exit 0
}

first_install(){
    require_root
    check_ubuntu
    init_state
    echo
    msg "Starting installation..."
    install_packages
    get_server_ip
    domain_setup
    setup_nginx
    setup_ssl || true
    install_xray
    create_banner
    firewall_setup
    install_expiry_timer
    backup_configs
    touch "$CONFIG_DIR/installed"
    ok "Base installation completed."
    show_info
    read -rp "Press Enter to continue..."
}

menu(){
    while true; do
        clear
        echo "╔══════════════════════════════════════════════════╗"
        echo "║       ZAINUXBRAND 😎 PREMIUM VPN SCRIPT         ║"
        echo "║                    v$SCRIPT_VERSION                    ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo "║ 1. Install / Update System                      ║"
        echo "║ 2. Setup Domain + Nginx                         ║"
        echo "║ 3. Setup / Renew SSL                            ║"
        echo "║ 4. Install / Configure Xray                     ║"
        echo "║ 5. Create SSH User                              ║"
        echo "║ 6. Delete SSH User                              ║"
        echo "║ 7. List SSH Users                               ║"
        echo "║ 8. User Details                                 ║"
        echo "║ 9. Server Information                           ║"
        echo "║ 10. Service Status / Restart                    ║"
        echo "║ 11. Backup Configuration                        ║"
        echo "║ 12. Auto Update Panel from GitHub               ║"
        echo "║ 13. Check Expired Users                         ║"
        echo "║ 14. View Logs                                   ║"
        echo "║ 15. UNINSTALL / CLEAN PANEL                     ║"
        echo "║ 0. Exit                                         ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo
        read -rp "Select option: " OPTION

        case "$OPTION" in
            1) system_update; install_packages ;;
            2) get_server_ip; domain_setup; setup_nginx ;;
            3) setup_ssl ;;
            4) configure_xray ;;
            5) create_user ;;
            6) delete_user ;;
            7) list_users ;;
            8) show_user_details ;;
            9) show_info ;;
            10) service_status; restart_services ;;
            11) backup_configs ;;
            12) self_update ;;
            13) lock_expired_users ;;
            14) echo; tail -n 100 "$LOG_FILE" 2>/dev/null || true ;;
            15) uninstall_panel ;;
            0) echo "Goodbye."; exit 0 ;;
            *) warn "Invalid option." ;;
        esac

        echo
        read -rp "Press Enter to return to menu..."
    done
}

main(){
    require_root

    if [[ "${1:-}" == "--expire-check" ]]; then
        lock_expired_users
        exit 0
    fi

    if [[ "${1:-}" == "--install" ]]; then
        check_ubuntu
        first_install
        exit 0
    fi

    check_ubuntu
    init_state

    if [[ ! -f "$CONFIG_DIR/installed" ]]; then
        echo
        echo "First-time installation detected."
        read -rp "Start installation now? [y/N]: " ANSWER
        if [[ "${ANSWER,,}" == "y" ]]; then
            first_install
        fi
    fi

    menu
}

main "$@"
