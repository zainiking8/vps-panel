#!/usr/bin/env bash
# ============================================================
# ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
# Ubuntu 20.04 / 22.04 / 24.04
# ============================================================

set -Eeuo pipefail

SCRIPT_NAME="ZAINUXBRAND 😎 PREMIUM VPN SCRIPT"
SCRIPT_VERSION="1.0.0"
CONFIG_DIR="/etc/zainuxbrand"
BACKUP_DIR="/root/zainuxbrand-backups"
LOG_FILE="/var/log/zainuxbrand.log"

mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
touch "$LOG_FILE"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

msg()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

trap 'err "Command failed at line $LINENO"; exit 1' ERR

clear
echo "======================================================"
echo "       $SCRIPT_NAME"
echo "                  Version $SCRIPT_VERSION"
echo "======================================================"
echo
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        err "Please run this script as root."
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        err "Cannot detect operating system."
        exit 1
    fi

    . /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        err "This installer is designed for Ubuntu."
        err "Detected: ${PRETTY_NAME:-unknown}"
        exit 1
    fi

    case "${VERSION_ID:-}" in
        20.04|22.04|24.04)
            ok "Supported Ubuntu: ${PRETTY_NAME}"
            ;;
        *)
            warn "Ubuntu ${VERSION_ID:-unknown} detected."
            warn "Supported versions: 20.04 / 22.04 / 24.04"
            ;;
    esac
}

install_packages() {
    msg "Updating package lists..."
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get upgrade -y

    apt-get install -y \
        curl wget ca-certificates gnupg unzip jq \
        openssl cron socat nginx certbot \
        python3-certbot-nginx ufw

    ok "Required packages installed."
}
get_server_ip() {
    SERVER_IP="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"

    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP="unknown"
    fi

    echo "$SERVER_IP" > "$CONFIG_DIR/server_ip"
    msg "Server IPv4: $SERVER_IP"
}

domain_setup() {
    echo
    read -rp "Enter your SSL/Xray subdomain: " DOMAIN

    if [[ -z "$DOMAIN" ]]; then
        err "Domain cannot be empty."
        return 1
    fi

    DOMAIN="${DOMAIN,,}"

    if [[ "$DOMAIN" == *" "* ]]; then
        err "Invalid domain."
        return 1
    fi

    echo "$DOMAIN" > "$CONFIG_DIR/domain"

    msg "Checking DNS for $DOMAIN ..."

    RESOLVED_IP="$(getent ahostsv4 "$DOMAIN" 2>/dev/null |
        awk 'NR==1{print $1}' || true)"

    if [[ -n "$RESOLVED_IP" ]]; then
        msg "DNS resolves to: $RESOLVED_IP"

        if [[ "$SERVER_IP" != "unknown" && "$RESOLVED_IP" != "$SERVER_IP" ]]; then
            warn "Domain does not currently resolve to this VPS."
            warn "SSL certificate issuance may fail."
        else
            ok "DNS appears correctly configured."
        fi
    else
        warn "Domain could not be resolved."
        warn "Create an A record pointing to this VPS first."
    fi
}

load_domain() {
    if [[ -f "$CONFIG_DIR/domain" ]]; then
        DOMAIN="$(cat "$CONFIG_DIR/domain")"
    else
        domain_setup
    fi
}
setup_nginx() {
    load_domain

    msg "Configuring Nginx..."

    cat > /etc/nginx/sites-available/zainuxbrand.conf <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN};

    location / {
        return 200 "ZAINUXBRAND 😎 PREMIUM VPN SCRIPT\\n";
        add_header Content-Type text/plain;
    }
}
EOF

    ln -sf \
        /etc/nginx/sites-available/zainuxbrand.conf \
        /etc/nginx/sites-enabled/zainuxbrand.conf

    rm -f /etc/nginx/sites-enabled/default

    nginx -t
    systemctl enable nginx
    systemctl restart nginx

    ok "Nginx configured."
}

setup_ssl() {
    load_domain

    msg "Requesting/renewing Let's Encrypt certificate..."

    if certbot --nginx \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email \
        --redirect; then

        ok "SSL certificate installed for $DOMAIN"
    else
        warn "Certificate request failed."
        warn "Check that DNS points to this VPS and port 80 is reachable."
        return 1
    fi

    systemctl enable certbot.timer 2>/dev/null || true
    systemctl start certbot.timer 2>/dev/null || true
}
install_xray() {
    msg "Installing Xray..."

    if command -v xray >/dev/null 2>&1; then
        ok "Xray is already installed."
        return 0
    fi

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
        @ install

    if command -v xray >/dev/null 2>&1; then
        ok "Xray installed successfully."
    else
        err "Xray installation failed."
        return 1
    fi
}

xray_status() {
    echo
    systemctl --no-pager --full status xray 2>/dev/null || true
    echo

    if command -v xray >/dev/null 2>&1; then
        xray version || true
    fi
}

restart_services() {
    msg "Restarting services..."

    systemctl restart nginx 2>/dev/null || true
    systemctl restart xray 2>/dev/null || true

    ok "Services restart command completed."
}
create_banner() {
    cat > /etc/motd <<'EOF'
======================================================
       ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
======================================================
       Authorized server access only.
======================================================
EOF

    mkdir -p /etc/ssh/sshd_config.d

    cat > /etc/ssh/sshd_config.d/zainuxbrand-banner.conf <<'EOF'
Banner /etc/ssh/zainuxbrand-banner
EOF

    cat > /etc/ssh/zainuxbrand-banner <<'EOF'

======================================================
       ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
======================================================
       Authorized server access only.
======================================================

EOF

    if sshd -t 2>/dev/null; then
        systemctl restart ssh 2>/dev/null || \
        systemctl restart sshd 2>/dev/null || true
        ok "SSH branding enabled."
    else
        warn "SSH configuration test failed; banner not activated."
    fi
}

create_user() {
    echo
    read -rp "Username: " USERNAME

    if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        err "Invalid Linux username."
        return 1
    fi

    if id "$USERNAME" >/dev/null 2>&1; then
        warn "User already exists."
        return 0
    fi

    adduser --disabled-password --gecos "" "$USERNAME"
    passwd "$USERNAME"

    ok "User $USERNAME created."
}
delete_user() {
    echo
    read -rp "Username to delete: " USERNAME

    if [[ -z "$USERNAME" ]]; then
        return 1
    fi

    if [[ "$USERNAME" == "root" ]]; then
        err "Root user cannot be deleted."
        return 1
    fi

    if id "$USERNAME" >/dev/null 2>&1; then
        userdel -r "$USERNAME" 2>/dev/null || userdel "$USERNAME"
        ok "User $USERNAME deleted."
    else
        warn "User does not exist."
    fi
}

list_users() {
    echo
    echo "================ SSH USERS ================"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd |
    while read -r user; do
        echo " - $user"
    done
    echo "============================================"
}

backup_configs() {
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"

    mkdir -p "$BACKUP_DIR/$stamp"

    cp -a "$CONFIG_DIR" "$BACKUP_DIR/$stamp/" 2>/dev/null || true
    cp -a /etc/nginx "$BACKUP_DIR/$stamp/" 2>/dev/null || true
    cp -a /usr/local/etc/xray "$BACKUP_DIR/$stamp/" 2>/dev/null || true

    ok "Backup created: $BACKUP_DIR/$stamp"
}
firewall_setup() {
    msg "Configuring basic firewall..."

    ufw allow OpenSSH >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true

    echo "y" | ufw enable >/dev/null 2>&1 || true

    ok "Firewall configured for SSH/HTTP/HTTPS."
}

show_info() {
    load_domain

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
    echo
}

logs() {
    echo
    echo "============= ZAINUXBRAND LOG ============="
    tail -n 100 "$LOG_FILE" 2>/dev/null || true
    echo
}
first_install() {
    require_root
    check_ubuntu

    msg "Starting installation..."
    install_packages
    get_server_ip
    domain_setup
    setup_nginx
    setup_ssl
    install_xray
    create_banner
    firewall_setup
    backup_configs

    ok "Base installation completed."
    echo
    show_info
    read -rp "Press Enter to continue..."
}

menu() {
    while true; do
        clear

        echo "╔══════════════════════════════════════════════╗"
        echo "║      ZAINUXBRAND 😎 PREMIUM VPN SCRIPT      ║"
        echo "╠══════════════════════════════════════════════╣"
        echo "║ 1. Install / Update System                   ║"
        echo "║ 2. Setup Domain + Nginx                      ║"
        echo "║ 3. Setup / Renew SSL                         ║"
        echo "║ 4. Install / Check Xray                      ║"
        echo "║ 5. Create SSH User                           ║"
        echo "║ 6. Delete SSH User                           ║"
        echo "║ 7. List SSH Users                            ║"
        echo "║ 8. Server Information                        ║"
        echo "║ 9. Service Status / Restart                  ║"
        echo "║ 10. Backup Configuration                     ║"
        echo "║ 11. View Logs                                ║"
        echo "║ 0. Exit                                      ║"
        echo "╚══════════════════════════════════════════════╝"
        echo

        read -rp "Select option: " OPTION

        case "$OPTION" in
            1)
                install_packages
                ;;
            2)
                get_server_ip
                domain_setup
                setup_nginx
                ;;
            3)
                setup_ssl
                ;;
            4)
                install_xray
                xray_status
                ;;
            5)
                create_user
                ;;
            6)
                delete_user
                ;;
            7)
                list_users
                ;;
            8)
                get_server_ip
                show_info
                ;;
            9)
                xray_status
                restart_services
                ;;
            10)
                backup_configs
                ;;
            11)
                logs
                ;;
            0)
                echo "Goodbye."
                exit 0
                ;;
            *)
                warn "Invalid option."
                ;;
        esac

        echo
        read -rp "Press Enter to return to menu..."
    done
}
main() {
    require_root
    check_ubuntu

    if [[ ! -f "$CONFIG_DIR/installed" ]]; then
        echo
        echo "First-time installation detected."
        read -rp "Start installation now? [y/N]: " ANSWER

        if [[ "${ANSWER,,}" == "y" ]]; then
            first_install
            touch "$CONFIG_DIR/installed"
        fi
    fi

    menu
}

main "$@"
