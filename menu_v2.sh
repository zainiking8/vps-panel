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
USER_DIR="$CONFIG_DIR/users"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
DNSTT_BIN="/usr/local/bin/dnstt-server"
DNSTT_DIR="/etc/dnstt"
DNSTT_SERVICE="/etc/systemd/system/dnstt.service"
LIMIT_TIMER="/etc/systemd/system/zainux-expiry.timer"

mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$USER_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
msg(){ echo -e "${CYAN}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERROR]${NC} $*"; }
trap 'err "Command failed at line $LINENO"' ERR

require_root(){ [[ $EUID -eq 0 ]] || { err "Run as root."; exit 1; }; }
check_ubuntu(){
  [[ -f /etc/os-release ]] || { err "Cannot detect OS."; exit 1; }
  . /etc/os-release
  [[ ${ID:-} == ubuntu ]] || { err "This script is for Ubuntu."; exit 1; }
  case "${VERSION_ID:-}" in 20.04|22.04|24.04) ok "Supported Ubuntu: $PRETTY_NAME";;
  *) warn "Ubuntu ${VERSION_ID:-unknown}; tested target: 20.04/22.04/24.04";; esac
}
server_ip(){
  SERVER_IP="$(curl -4fsS --max-time 8 https://api.ipify.org || true)"
  [[ -n "$SERVER_IP" ]] || SERVER_IP="unknown"
  echo "$SERVER_IP" > "$CONFIG_DIR/server_ip"
}
load_domain(){
  [[ -f "$CONFIG_DIR/domain" ]] && DOMAIN="$(<"$CONFIG_DIR/domain")" || DOMAIN=""
}
load_slowdns(){
  [[ -f "$CONFIG_DIR/slowdns_domain" ]] && SLOWDNS_DOMAIN="$(<"$CONFIG_DIR/slowdns_domain")" || SLOWDNS_DOMAIN=""
}
save_kv(){ printf '%s\n' "$2" > "$1"; chmod 600 "$1"; }

install_packages(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl wget ca-certificates gnupg unzip jq openssl cron nginx certbot ufw \
    git golang-go build-essential iptables
  ok "Required packages installed."
}
domain_setup(){
  server_ip
  read -rp "Main SSL/Xray domain (e.g. vpn.example.com): " DOMAIN
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || { err "Invalid domain."; return 1; }
  DOMAIN="${DOMAIN,,}"
  save_kv "$CONFIG_DIR/domain" "$DOMAIN"
  RESOLVED_IP="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
  echo
  msg "Main domain: $DOMAIN"
  msg "Server IP : $SERVER_IP"
  [[ "$RESOLVED_IP" == "$SERVER_IP" ]] && ok "DNS is pointing correctly." ||
    warn "DNS is not confirmed on this VPS. Create an A record first."
}
slowdns_setup(){
  server_ip
  echo
  echo "SlowDNS requires a separate delegated NS zone."
  echo "Example:"
  echo "  ns1.example.com  A   $SERVER_IP"
  echo "  t.example.com    NS  ns1.example.com"
  echo
  read -rp "SlowDNS tunnel domain (e.g. t.example.com): " SLOWDNS_DOMAIN
  read -rp "Authoritative NS host (e.g. ns1.example.com): " SLOWDNS_NS
  [[ "$SLOWDNS_DOMAIN" =~ ^[A-Za-z0-9.-]+$ && "$SLOWDNS_NS" =~ ^[A-Za-z0-9.-]+$ ]] ||
    { err "Invalid SlowDNS domain/NS."; return 1; }
  SLOWDNS_DOMAIN="${SLOWDNS_DOMAIN,,}"; SLOWDNS_NS="${SLOWDNS_NS,,}"
  save_kv "$CONFIG_DIR/slowdns_domain" "$SLOWDNS_DOMAIN"
  save_kv "$CONFIG_DIR/slowdns_ns" "$SLOWDNS_NS"
  ok "SlowDNS settings saved."
  warn "The DNS records must be created at your registrar/DNS provider; the script cannot create them automatically."
}
nginx_setup(){
  load_domain; [[ -n "$DOMAIN" ]] || domain_setup
  cat >/etc/nginx/sites-available/zainuxbrand.conf <<EOF
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
  systemctl enable --now nginx
  ok "Nginx configured on port 80."
}
ssl_setup(){
  load_domain; [[ -n "$DOMAIN" ]] || { err "Set main domain first."; return 1; }
  systemctl stop xray 2>/dev/null || true
  systemctl stop nginx 2>/dev/null || true
  msg "Requesting Let's Encrypt certificate for $DOMAIN..."
  certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos \
    --register-unsafely-without-email || { systemctl start nginx 2>/dev/null || true; return 1; }
  systemctl start nginx
  ok "Certificate installed."
}
install_xray(){
  if ! command -v xray >/dev/null 2>&1; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
  fi
  command -v xray >/dev/null 2>&1 || { err "Xray installation failed."; return 1; }
  ok "Xray installed."
}
xray_setup(){
  load_domain
  [[ -n "$DOMAIN" ]] || { err "Set main domain first."; return 1; }
  install_xray
  [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]] ||
    { err "Install SSL certificate for $DOMAIN first."; return 1; }
  mkdir -p /usr/local/etc/xray
  UUID="$(cat /proc/sys/kernel/random/uuid)"
  save_kv "$CONFIG_DIR/xray_uuid" "$UUID"
  cat >"$XRAY_CONFIG" <<EOF
{
  "log": {"loglevel":"warning"},
  "inbounds": [{
    "listen":"0.0.0.0",
    "port":443,
    "protocol":"vless",
    "settings":{"clients":[{"id":"$UUID","email":"zainuxbrand@server"}],"decryption":"none"},
    "streamSettings":{
      "network":"ws",
      "security":"tls",
      "tlsSettings":{"certificates":[{"certificateFile":"/etc/letsencrypt/live/$DOMAIN/fullchain.pem","keyFile":"/etc/letsencrypt/live/$DOMAIN/privkey.pem"}]},
      "wsSettings":{"path":"/zainuxbrand"}
    }
  }],
  "outbounds":[{"protocol":"freedom","settings":{}}]
}
EOF
  xray -test -config "$XRAY_CONFIG"
  systemctl enable --now xray
  systemctl restart xray
  save_kv "$CONFIG_DIR/xray_domain" "$DOMAIN"
  save_kv "$CONFIG_DIR/xray_path" "/zainuxbrand"
  echo
  ok "Xray VLESS + WebSocket + TLS server created."
  echo "Address : $DOMAIN"
  echo "Port    : 443"
  echo "UUID    : $UUID"
  echo "Path    : /zainuxbrand"
  echo "TLS     : enabled"
  echo "UDP     : supported through the Xray freedom outbound."
}
dnstt_install(){
  load_slowdns
  [[ -n "$SLOWDNS_DOMAIN" ]] || { err "Configure SlowDNS first."; return 1; }
  [[ -f "$CONFIG_DIR/slowdns_ns" ]] || { err "Configure SlowDNS NS host first."; return 1; }
  command -v go >/dev/null 2>&1 || apt-get install -y golang-go
  tmp="$(mktemp -d)"
  git clone --depth 1 https://github.com/getlantern/dnstt.git "$tmp/dnstt"
  (cd "$tmp/dnstt/server" && go build -o "$DNSTT_BIN" .)
  mkdir -p "$DNSTT_DIR"
  if [[ ! -f "$DNSTT_DIR/server.key" ]]; then
    "$DNSTT_BIN" -gen-key -privkey-file "$DNSTT_DIR/server.key" -pubkey-file "$DNSTT_DIR/server.pub"
    chmod 600 "$DNSTT_DIR/server.key"
  fi
  cat >"$DNSTT_SERVICE" <<EOF
[Unit]
Description=DNSTT SlowDNS Server
After=network.target
[Service]
Type=simple
ExecStart=$DNSTT_BIN -udp :5300 -privkey-file $DNSTT_DIR/server.key $SLOWDNS_DOMAIN
Restart=on-failure
RestartSec=2
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now dnstt
  iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null ||
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
  ok "SlowDNS server installed and listening via UDP/53 -> 5300."
  echo "Tunnel domain : $SLOWDNS_DOMAIN"
  echo "NS host       : $(<"$CONFIG_DIR/slowdns_ns")"
  echo "Public key    : $(<"$DNSTT_DIR/server.pub")"
  echo
  warn "Create the A record for the NS host and the NS delegation before testing."
}
firewall_setup(){
  ufw allow OpenSSH >/dev/null 2>&1 || true
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
  ufw allow 53/udp >/dev/null 2>&1 || true
  echo y | ufw enable >/dev/null 2>&1 || true
  ok "Firewall: SSH, HTTP, HTTPS and DNS/UDP allowed."
}
create_banner(){
  cat >/etc/motd <<'EOF'
======================================================
       ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
======================================================
       Authorized server access only.
======================================================
EOF
  mkdir -p /etc/ssh/sshd_config.d
  cat >/etc/ssh/sshd_config.d/zainuxbrand-banner.conf <<'EOF'
Banner /etc/ssh/zainuxbrand-banner
EOF
  cat >/etc/ssh/zainuxbrand-banner <<'EOF'

======================================================
       ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
======================================================
       Authorized server access only.
======================================================

EOF
  sshd -t && (systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true)
}
account_expiry_worker(){
  mkdir -p "$USER_DIR"
  for f in "$USER_DIR"/*.conf; do
    [[ -f "$f" ]] || continue
    . "$f"
    [[ -n "${EXPIRE:-}" ]] || continue
    if [[ "$(date -u +%s)" -ge "$(date -u -d "$EXPIRE" +%s 2>/dev/null || echo 0)" ]]; then
      passwd -l "$USERNAME" >/dev/null 2>&1 || true
      sed -i 's/^STATUS=.*/STATUS=expired/' "$f"
    fi
  done
}
install_expiry_timer(){
  cat >/usr/local/sbin/zainux-expiry-check <<'EOF'
#!/usr/bin/env bash
set -u
USER_DIR="/etc/zainuxbrand/users"
for f in "$USER_DIR"/*.conf; do
  [ -f "$f" ] || continue
  . "$f"
  [ -n "${EXPIRE:-}" ] || continue
  if [ "$(date -u +%s)" -ge "$(date -u -d "$EXPIRE" +%s 2>/dev/null || echo 0)" ]; then
    passwd -l "$USERNAME" >/dev/null 2>&1 || true
    sed -i 's/^STATUS=.*/STATUS=expired/' "$f"
  fi
done
EOF
  chmod 700 /usr/local/sbin/zainux-expiry-check
  cat >/etc/systemd/system/zainux-expiry.service <<'EOF'
[Unit]
Description=ZAINUXBRAND account expiry check
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zainux-expiry-check
EOF
  cat >"$LIMIT_TIMER" <<'EOF'
[Unit]
Description=Run ZAINUXBRAND expiry check
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now zainux-expiry.timer
}
random_pass(){ tr -dc 'A-Za-z0-9@#%+=_' </dev/urandom | head -c 12 || true; }
create_user(){
  read -rp "Username: " USERNAME
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { err "Invalid username."; return 1; }
  if id "$USERNAME" >/dev/null 2>&1; then err "User already exists."; return 1; fi
  read -rp "Password (blank = auto): " PASSWORD
  [[ -n "$PASSWORD" ]] || PASSWORD="$(random_pass)"
  read -rp "IP limit (1-10, informational/enforced by session policy): " IPLIMIT
  IPLIMIT="${IPLIMIT:-1}"
  read -rp "GB limit (0 = unlimited): " GBLIMIT
  GBLIMIT="${GBLIMIT:-0}"
  read -rp "Expiry days (0 = never): " DAYS
  DAYS="${DAYS:-0}"
  if [[ "$DAYS" == "0" ]]; then EXPIRE="never"; else EXPIRE="$(date -u -d "+$DAYS days" '+%Y-%m-%d %H:%M:%S UTC')"; fi

  adduser --disabled-password --gecos "" "$USERNAME" >/dev/null
  echo "$USERNAME:$PASSWORD" | chpasswd
  CFG="$USER_DIR/$USERNAME.conf"
  {
    printf 'USERNAME=%q\n' "$USERNAME"
    printf 'IPLIMIT=%q\n' "$IPLIMIT"
    printf 'GBLIMIT=%q\n' "$GBLIMIT"
    printf 'EXPIRE=%q\n' "$EXPIRE"
    printf 'STATUS=%q\n' active
    printf 'CREATED=%q\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  } >"$CFG"
  chmod 600 "$CFG"
  echo
  echo "======================================================"
  echo "        SSH ACCOUNT CREATED"
  echo "======================================================"
  echo "Username   : $USERNAME"
  echo "Password   : $PASSWORD"
  echo "IP Limit   : $IPLIMIT"
  echo "GB Limit   : $GBLIMIT"
  echo "Expire     : $EXPIRE"
  echo "Status     : active"
  echo "SSH Host   : ${SERVER_IP:-$(curl -4fsS --max-time 5 https://api.ipify.org || echo unknown)}"
  echo "SSH Port   : 22"
  echo "Payload    : GET / HTTP/1.1 [Host: your-domain] (optional client payload)"
  echo "======================================================"
}
delete_user(){
  read -rp "Username to delete: " USERNAME
  [[ "$USERNAME" != root ]] || { err "Root cannot be deleted."; return 1; }
  if id "$USERNAME" >/dev/null 2>&1; then userdel -r "$USERNAME" 2>/dev/null || userdel "$USERNAME"; rm -f "$USER_DIR/$USERNAME.conf"; ok "User deleted."; else warn "User does not exist."; fi
}
list_users(){
  echo "================ SSH USERS ================"
  printf '%-18s %-8s %-8s %-24s %-10s\n' USER IP_LIMIT GB_LIMIT EXPIRE STATUS
  for f in "$USER_DIR"/*.conf; do
    [[ -f "$f" ]] || continue
    . "$f"
    printf '%-18s %-8s %-8s %-24s %-10s\n' "$USERNAME" "$IPLIMIT" "$GBLIMIT" "$EXPIRE" "$STATUS"
  done
  echo "==========================================="
}
user_info(){
  read -rp "Username: " USERNAME
  f="$USER_DIR/$USERNAME.conf"
  [[ -f "$f" ]] || { err "Account record not found."; return 1; }
  . "$f"
  echo "User       : $USERNAME"
  echo "IP limit   : $IPLIMIT"
  echo "GB limit   : $GBLIMIT"
  echo "Expiry     : $EXPIRE"
  echo "Status     : $STATUS"
}
server_info(){
  server_ip; load_domain; load_slowdns
  echo
  echo "======================================================"
  echo "              SERVER INFORMATION"
  echo "======================================================"
  echo "Brand       : $SCRIPT_NAME"
  echo "Version     : $SCRIPT_VERSION"
  echo "IP          : $SERVER_IP"
  echo "Main domain : ${DOMAIN:-not configured}"
  echo "SlowDNS     : ${SLOWDNS_DOMAIN:-not configured}"
  echo "Xray        : $(systemctl is-active xray 2>/dev/null || echo not-installed)"
  echo "DNSTT       : $(systemctl is-active dnstt 2>/dev/null || echo not-installed)"
  echo "======================================================"
}
backup_configs(){
  stamp="$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BACKUP_DIR/$stamp"
  cp -a "$CONFIG_DIR" "$BACKUP_DIR/$stamp/" 2>/dev/null || true
  cp -a /etc/nginx "$BACKUP_DIR/$stamp/" 2>/dev/null || true
  cp -a /usr/local/etc/xray "$BACKUP_DIR/$stamp/" 2>/dev/null || true
  ok "Backup: $BACKUP_DIR/$stamp"
}
status_restart(){
  echo "----- Xray -----"; systemctl --no-pager --full status xray 2>/dev/null || true
  echo "----- DNSTT -----"; systemctl --no-pager --full status dnstt 2>/dev/null || true
  echo "----- Nginx -----"; systemctl --no-pager --full status nginx 2>/dev/null || true
  echo
  read -rp "Restart Xray/Nginx/DNSTT now? [y/N]: " A
  [[ "${A,,}" == y ]] && { systemctl restart xray 2>/dev/null || true; systemctl restart nginx 2>/dev/null || true; systemctl restart dnstt 2>/dev/null || true; ok "Restart complete."; }
}
first_install(){
  install_packages
  server_ip
  domain_setup
  nginx_setup
  ssl_setup || warn "SSL setup did not complete; run option 3 after fixing DNS."
  xray_setup || warn "Xray setup did not complete; run option 4 after SSL is ready."
  create_banner
  slowdns_setup
  dnstt_install || warn "SlowDNS setup did not complete; fix DNS and rerun option 5."
  firewall_setup
  install_expiry_timer
  backup_configs
  ok "Base installation completed."
}
menu(){
  while true; do
    clear
    echo "╔══════════════════════════════════════════════════╗"
    echo "║      ZAINUXBRAND 😎 PREMIUM VPN SCRIPT          ║"
    echo "╠══════════════════════════════════════════════════╣"
    echo "║ 1. Install / Update System                       ║"
    echo "║ 2. Setup Main Domain + Nginx                     ║"
    echo "║ 3. Setup / Renew Main SSL                        ║"
    echo "║ 4. Install / Create Xray VLESS Server            ║"
    echo "║ 5. Setup / Install SlowDNS                       ║"
    echo "║ 6. Create SSH User                               ║"
    echo "║ 7. Delete SSH User                               ║"
    echo "║ 8. List SSH Users                                ║"
    echo "║ 9. Show User Details                             ║"
    echo "║ 10. Server Information                           ║"
    echo "║ 11. Service Status / Restart                     ║"
    echo "║ 12. Backup Configuration                         ║"
    echo "║ 13. View Logs                                    ║"
    echo "║ 0. Exit                                          ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo
    read -rp "Select option: " OPTION
    case "$OPTION" in
      1) install_packages;;
      2) domain_setup; nginx_setup;;
      3) ssl_setup;;
      4) xray_setup;;
      5) slowdns_setup; dnstt_install;;
      6) create_user;;
      7) delete_user;;
      8) list_users;;
      9) user_info;;
      10) server_info;;
      11) status_restart;;
      12) backup_configs;;
      13) tail -n 100 "$LOG_FILE" 2>/dev/null || true;;
      0) exit 0;;
      *) warn "Invalid option.";;
    esac
    echo
    read -rp "Press Enter to return to menu..."
  done
}
main(){
  require_root
  check_ubuntu
  install_expiry_timer
  if [[ ! -f "$CONFIG_DIR/installed" ]]; then
    echo "First-time installation detected."
    read -rp "Start installation now? [y/N]: " ANSWER
    if [[ "${ANSWER,,}" == y ]]; then first_install; touch "$CONFIG_DIR/installed"; fi
  fi
  menu
}
main "$@"
