#!/usr/bin/env bash
#==============================================================================
#   ZAINU X BRAND 😎  —  PREMIUM VPN SCRIPT  v2.0
#   ALL PROTOCOLS + ACCOUNT SYSTEM (IP limit / GB limit / expiry)
#   SSH • Dropbear • SSL-TLS • Websocket(TLS+nonTLS) • UDP-Custom
#   Xray: VLESS • VMess • Trojan • Reality • Shadowsocks
#   SlowDNS • Hysteria2 • WireGuard • OpenVPN
#   Ubuntu 20.04+ / Debian 11+
#==============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

BRAND="ZAINU X BRAND 😎"; TAG="ZAINU-X-BRAND"; VER="2.0"
LOG="/var/log/zainu-vpn.log"
ZDIR="/etc/zainu"; DB="$ZDIR/accounts.db"; MARKER="$ZDIR/installed"

# ports
PORT_SSH=22; PORT_DROP=143; PORT_SSL=9443; PORT_WS_HTTP=80; PORT_WS_TLS=443
PORT_UDP=7100; PORT_VMESS_TCP=10086; PORT_REALITY=8443; PORT_GRPC=2053
PORT_SS=8388; PORT_SLOWDNS=53; PORT_HY2=443; PORT_WG=51820; PORT_OVPN=1194
PORT_VMESS_WS=20001; PORT_VLESS_WS=20002; PORT_TROJAN_WS=20003

# runtime inputs
DOMAIN=""; EMAIL=""; CF_HOST=""; SLOWDNS_NS=""; SLOWDNS_PASS=""

#────────────────────────────── Rainbow Colors ────────────────────────────────
R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'
B=$'\033[1;34m'; M=$'\033[1;35m'; W=$'\033[1;37m'; K=$'\033[0m'
RD=$'\033[0;31m'; GN=$'\033[0;32m'; YL=$'\033[0;33m'; CY=$'\033[0;36m'; BL=$'\033[0;34m'; MG=$'\033[0;35m'

ok(){ echo -e "${G}[✓]${K} $*" | tee -a "$LOG"; }
wr(){ echo -e "${Y}[!]${K} $*" | tee -a "$LOG"; }
er(){ echo -e "${R}[✗]${K} $*" | tee -a "$LOG" >&2; }
die(){ er "$*"; exit 1; }
hr(){ echo -e "${M}════════════════════════════════════════════════════════════${K}"; }
step(){ echo -e "\n${C}▶▶ $*${K}" | tee -a "$LOG"; }

rainbow(){ # text
  local t="$1" i=0 c; local cols=( $R $Y $G $C $B $M )
  while read -rn1 ch; do
    [[ -z "$ch" ]] && { printf ' '; continue; }
    c="${cols[$((i%6))]}"; printf '%b%s' "$c" "$ch"; i=$((i+1))
  done <<<"$t"
  printf '%b' "$K"
}

brand_banner() {
  echo
  echo -e "${C}╔════════════════════════════════════════════════════════════╗${K}"
  echo -ne "║  "; rainbow "ZAINU X BRAND 😎"; printf '  %b\n' "$K"
  echo -e "${G}║           PREMIUM VPN SCRIPT  v${VER}${K}"
  echo -e "${Y}║   ALL PROTOCOLS • REAL TLS • CLOUDFLARE • ACCOUNTS${K}"
  echo -e "${M}╚════════════════════════════════════════════════════════════╝${K}"
  echo
}

get_pubip(){ curl -s4 https://api.ipify.org 2>/dev/null || curl -s4 https://ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"; }
rand_str(){ head -c "${1:-16}" /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c"${1:-16}"; }
rand_hex(){ openssl rand -hex "${1:-8}"; }

#────────────────────────────── Help / Args ───────────────────────────────────
print_help(){
  brand_banner
  cat <<EOF
${G}Usage:${K} sudo bash zainu-vpn.sh [OPTIONS]

  --install       full protocol install (first run)
  --menu          open management menu (after install)
  --create        quick create an account (prompts IP/GB/expiry)
  --list          list accounts
  --uninstall      remove everything
  --help, -h      this help

${Y}Without args:${K} installs if not yet installed, otherwise opens the menu.
EOF
}

ACTION="auto"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)   ACTION="install"; shift ;;
    --menu)      ACTION="menu"; shift ;;
    --create)    ACTION="create"; shift ;;
    --list)      ACTION="list"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --domain)    DOMAIN="$2"; shift 2 ;;
    --email)     EMAIL="$2"; shift 2 ;;
    --cfhost)    CF_HOST="$2"; shift 2 ;;
    --slownsdn)  SLOWDNS_NS="$2"; shift 2 ;;
    --slowpass)   SLOWDNS_PASS="$2"; shift 2 ;;
    --help|-h)   print_help; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
done

is_installed(){ [[ -f "$MARKER" ]]; }

#────────────────────────────── Preflight ─────────────────────────────────────
preflight(){
  hr; brand_banner; hr
  [[ $EUID -eq 0 ]] || die "Run as root: sudo bash zainu-vpn.sh"
  : > "$LOG" 2>/dev/null || { LOG="/tmp/zainu-vpn.log"; : > "$LOG"; }
  ok "Log: $LOG"
  [[ -f /etc/os-release ]] || die "Cannot detect OS."
  . /etc/os-release
  case "$ID" in ubuntu|debian) ok "OS: $PRETTY_NAME" ;; *) die "Unsupported distro '$ID'." ;; esac
  PUBIP="$(get_pubip)"; ok "Public IP: $PUBIP"
  echo -e "\n${Y}This installs ALL VPN protocols + account system on this VPS.${K}"
  read -r -p "Proceed? [y/N]: " ans
  [[ "${ans:-N}" =~ ^[Yy]$ ]] || die "Aborted."
  hr
}

get_inputs(){
  step "Collecting setup details"
  [[ -z "$DOMAIN" ]]    && read -r -p "Domain (A-recorded to VPS): " DOMAIN
  [[ -z "$EMAIL" ]]     && read -r -p "Email for Let's Encrypt: " EMAIL
  [[ -z "$CF_HOST" ]]   && { read -r -p "Cloudflare-proxied host for ws:// links [$DOMAIN]: " CF_HOST; CF_HOST="${CF_HOST:-$DOMAIN}"; }
  [[ -z "$SLOWDNS_NS" ]]   && read -r -p "SlowDNS NS subdomain (ns1.domain.com): " SLOWDNS_NS
  [[ -z "$SLOWDNS_PASS" ]] && { SLOWDNS_PASS="$(rand_str 16)"; wr "SlowDNS password: $SLOWDNS_PASS"; }
  : "${DOMAIN:?--domain required}"; : "${EMAIL:?--email required}"
  [[ -n "$CF_HOST" ]] || CF_HOST="$DOMAIN"
  ok "Domain=$DOMAIN  CF=$CF_HOST  NS=$SLOWDNS_NS"
  hr
}

#────────────────────────────── 1. Dependencies ─────────────────────────────
install_deps(){
  step "[1/13] Dependencies"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get -y -o Dpkg::Options::="--force-confold" upgrade
  apt-get -y -o Dpkg::Options::="--force-confold" install -y \
    curl wget git unzip tar gzip ca-certificates gnupg lsb-release \
    software-properties-common build-essential qrencode jq bc \
    net-tools dnsutils iproute2 iputils-ping socat iptables \
    nginx dropbear stunnel4 chrony cron \
    python3 python3-pip
  mkdir -p "$ZDIR" /var/www/html
  ok "Dependencies ready"
}

#────────────────────────────── 2. SSH + Dropbear ───────────────────────────
install_ssh_dropbear(){
  step "[2/13] OpenSSH (branded banner) + Dropbear (tunnel)"
  cat > /etc/issue.net <<EOF

        ${BRAND}  —  PREMIUM VPN
        Authorized access only. Powered by ${BRAND}

EOF
  local S=/etc/ssh/sshd_config
  cp -n "$S" "$S.bak.$(date +%s)" 2>/dev/null || true
  set_sshd(){ if grep -qE "^#?\s*$1\b" "$S"; then sed -i "s|^#\?\s*$1\b.*|$1 $2|" "$S"; else echo "$1 $2" >> "$S"; fi; }
  set_sshd Port "$PORT_SSH"; set_sshd PermitRootLogin yes; set_sshd PasswordAuthentication yes
  set_sshd PubkeyAuthentication yes; set_sshd Banner /etc/issue.net; set_sshd Protocol 2
  mkdir -p /etc/ssh/sshd_config.d
  sshd -t 2>/dev/null || die "sshd syntax error"
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
  ok "OpenSSH on $PORT_SSH (brand banner)"

  mkdir -p /etc/dropbear
  cat > /etc/default/dropbear <<EOF
DROPBEAR_PORT=$PORT_DROP
DROPBEAR_EXTRA_ARGS="-p $PORT_DROP -I 3600 -m -K 300"
EOF
  systemctl enable --now dropbear 2>/dev/null || systemctl restart dropbear 2>/dev/null || true
  ok "Dropbear (tunnel) on $PORT_DROP"
}

#────────────────────────────── 3. SSL/TLS stunnel ─────────────────────────
install_ssl(){
  step "[3/13] SSL/TLS (stunnel on $PORT_SSL)"
  mkdir -p /etc/stunnel /etc/nginx/ssl
  [[ -f /etc/nginx/ssl/${DOMAIN}.crt ]] || openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout /etc/nginx/ssl/${DOMAIN}.key -out /etc/nginx/ssl/${DOMAIN}.crt -subj "/CN=$DOMAIN" 2>/dev/null || true
  cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/nginx/ssl/${DOMAIN}.crt
key  = /etc/nginx/ssl/${DOMAIN}.key
[dropbear]
accept = $PORT_SSL
connect = 127.0.0.1:$PORT_DROP
EOF
  sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || echo "ENABLED=1" > /etc/default/stunnel4
  systemctl enable --now stunnel4 2>/dev/null || true
  ok "Stunnel SSL on $PORT_SSL → wraps Dropbear"
}

#────────────────────────────── 4. TLS cert (Let's Encrypt) ─────────────────
install_cert(){
  step "[4/13] TLS certificate (Let's Encrypt)"
  apt-get -y -qq install certbot python3-certbot-nginx 2>/dev/null || true
  cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server; listen [::]:80 default_server;
    server_name $DOMAIN; root /var/www/html; index index.html;
}
EOF
  systemctl enable --now nginx 2>/dev/null || true; systemctl reload nginx 2>/dev/null || true
  if certbot --nginx -d "$DOMAIN" -m "$EMAIL" --non-interactive --agree-tos --redirect 2>>"$LOG"; then
    ok "Real TLS cert issued for $DOMAIN"
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"; KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    sed -i "s#^cert = .*#cert = $CERT_PATH#; s#^key = .*#key = $KEY_PATH#" /etc/stunnel/stunnel.conf 2>/dev/null || true
    cp "$CERT_PATH" /etc/nginx/ssl/${DOMAIN}.crt 2>/dev/null || true
    cp "$KEY_PATH"  /etc/nginx/ssl/${DOMAIN}.key 2>/dev/null || true
    systemctl restart stunnel4 2>/dev/null || true
  else
    wr "Let's Encrypt failed — using self-signed fallback."
    CERT_PATH="/etc/nginx/ssl/${DOMAIN}.crt"; KEY_PATH="/etc/nginx/ssl/${DOMAIN}.key"
  fi
  ok "Cert: $CERT_PATH"
}

#────────────────────────────── 5. Websocket nginx ─────────────────────────
install_websocket(){
  step "[5/13] Websocket (TLS 443 + nonTLS 80) → Xray"
  P_VMESS="/vmess-ws"; P_VLESS="/vless-ws"; P_TROJAN="/trojan-ws"
  cat > /etc/nginx/sites-available/default <<EOF
# ZAINU X BRAND — non-TLS (CF-compatible)
server {
  listen 80 default_server; listen [::]:80 default_server;
  server_name $DOMAIN; root /var/www/html; index index.html;
  location $P_VMESS  { proxy_http_version 1.1; proxy_set_header Host \$http_addr;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_VMESS_WS; }
  location $P_VLESS  { proxy_http_version 1.1; proxy_set_header Host \$http_addr;
    proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade";
    proxy_pass http://127.0.0.1:$PORT_VLESS_WS; }
  location $P_TROJAN { proxy_http_version 1.1; proxy_set_header Host \$http_addr;
    proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade";
    proxy_pass http://127.0.0.1:$PORT_TROJAN_WS; }
}
# ZAINU X BRAND — TLS (real cert)
server {
  listen 443 ssl http2 default_server; listen [::]:443 ssl http2 default_server;
  server_name $DOMAIN;
  ssl_certificate $CERT_PATH; ssl_certificate_key $KEY_PATH;
  ssl_protocols TLSv1.2 TLSv1.3; ssl_ciphers HIGH:!aNULL:!MD5;
  location $P_VMESS  { proxy_http_version 1.1; proxy_set_header Host \$http_addr;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_VMESS_WS; }
  location $P_VLESS  { proxy_http_version 1.1; proxy_set_header Host \$http_addr;
    proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade";
    proxy_pass http://127.0.0.1:$PORT_VLESS_WS; }
  location $P_TROJAN { proxy_http_version 1.1; proxy_set_header Host \$http_addr;
    proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade";
    proxy_pass http://127.0.0.1:$PORT_TROJAN_WS; }
}
EOF
  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  nginx -t 2>>"$LOG" || die "nginx config invalid"
  systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
  ok "nginx WS: TLS=443 nonTLS=80 paths=$P_VMESS,$P_VLESS,$P_TROJAN"
}

#────────────────────────────── 6. UDP Custom ───────────────────────────────
install_udp(){
  step "[6/13] UDP Custom ($PORT_UDP/udp)"
  cat > /usr/local/bin/zainu-udpgw.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading, sys, hashlib
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 7100
TARGETS = [("1.1.1.1", 53), ("8.8.8.8", 53), ("1.0.0.1", 53)]
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", PORT)); clients = {}
def forward(src, data):
    t = TARGETS[int(hashlib.md5(str(src).encode()).hexdigest(),16) % len(TARGETS)]
    try:
        u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); u.settimeout(5)
        u.sendto(data, t)
        while True:
            r, _ = u.recvfrom(65535)
            try: s.sendto(r, src)
            except: break
    except: pass
print(f"[ZAINU X BRAND] udpgw on udp/{PORT}", flush=True)
while True:
    try:
        data, src = s.recvfrom(65535)
        threading.Thread(target=forward, args=(src, data), daemon=True).start()
    except: continue
PYEOF
  chmod +x /usr/local/bin/zainu-udpgw.py
  cat > /etc/systemd/system/zainu-udpgw.service <<EOF
[Unit]
Description=ZAINU X BRAND UDP-Custom
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/zainu-udpgw.py $PORT_UDP
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable --now zainu-udpgw 2>/dev/null || true
  ok "UDP Custom on $PORT_UDP/udp"
}

#────────────────────────────── 7. Xray (all sub-protocols) ──────────────────
install_xray(){
  step "[7/13] Xray core (VLESS/VMess/Trojan/Reality/Shadowsocks)"
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>>"$LOG" || wr "Xray installer issue"
  UUID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
  TROJAN_PASS="$(rand_str 16)"; SS_PASS="$(rand_hex 8)"
  REALITY_PAIR="$(xray x25519 2>/dev/null || true)"
  PRIV_KEY="$(echo "$REALITY_PAIR" | awk -F': ' '/Private/{print $2}' | tr -d '\r\n')"
  PUB_KEY="$(echo "$REALITY_PAIR" | awk -F': ' '/Public/{print $2}' | tr -d '\r\n')"
  [[ -z "$PRIV_KEY" ]] && { PRIV_KEY="$(rand_hex 16)"; PUB_KEY="$(rand_hex 16)"; }
  SHORT_SID="$(rand_hex 4)"
  cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "tag":"vmess-ws","port":$PORT_VMESS_WS,"listen":"127.0.0.1","protocol":"vmess",
      "settings":{"clients":[{"id":"$UUID"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"$P_VMESS"}} },
    { "tag":"vmess-tcp","port":$PORT_VMESS_TCP,"protocol":"vmess",
      "settings":{"clients":[{"id":"$UUID"}]},"streamSettings":{"network":"tcp"} },
    { "tag":"vless-ws","port":$PORT_VLESS_WS,"listen":"127.0.0.1","protocol":"vless",
      "settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},
      "streamSettings":{"network":"ws","wsSettings":{"path":"$P_VLESS"}} },
    { "tag":"vless-reality","port":$PORT_REALITY,"protocol":"vless",
      "settings":{"clients":[{"id":"$UUID","flow":"xtls-rprx-vision"}],"decryption":"none"},
      "streamSettings":{"network":"tcp","security":"reality",
        "realitySettings":{"show":false,"dest":"$DOMAIN:443","xver":0,
        "serverNames":["$DOMAIN"],"privateKey":"$PRIV_KEY","shortIds":["$SHORT_SID"]}} },
    { "tag":"trojan-ws","port":$PORT_TROJAN_WS,"listen":"127.0.0.1","protocol":"trojan",
      "settings":{"clients":[{"password":"$TROJAN_PASS"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"$P_TROJAN"}} },
    { "tag":"trojan-grpc","port":$PORT_GRPC,"protocol":"trojan",
      "settings":{"clients":[{"password":"$TROJAN_PASS"}]},"streamSettings":{"network":"grpc","grpcSettings":{"serviceName":"trojan-grpc"}} },
    { "tag":"shadowsocks","port":$PORT_SS,"protocol":"shadowsocks",
      "settings":{"method":"aes-256-gcm","password":"$SS_PASS","network":"tcp,udp"} }
  ],
  "outbounds":[ {"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"} ]
}
EOF
  xray run -test -c /usr/local/etc/xray/config.json 2>>"$LOG" || wr "xray config test warning"
  systemctl enable --now xray 2>/dev/null || systemctl restart xray 2>/dev/null || true
  ok "Xray: VMess(WS/TCP) VLESS(WS/Reality) Trojan(WS/gRPC) SS"
  ok "UUID=$UUID  Trojan=$TROJAN_PASS  SS=$SS_PASS  RealityPub=$PUB_KEY"
}

#────────────────────────────── 8. SlowDNS (iodine) ─────────────────────────
install_slowdns(){
  step "[8/13] SlowDNS (iodine on UDP $PORT_SLOWDNS)"
  apt-get -y -qq install iodine 2>/dev/null || true
  cat > /etc/systemd/system/zainu-slowdns.service <<EOF
[Unit]
Description=ZAINU X BRAND SlowDNS (iodine)
After=network.target
[Service]
EnvironmentFile=/etc/default/zainu-slowdns
ExecStart=/usr/sbin/iodined -c -f -P \${SLOWDNS_PASS} 10.22.0.1 \${SLOWDNS_NS}
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  cat > /etc/default/zainu-slowdns <<EOF
SLOWDNS_NS=$SLOWDNS_NS
SLOWDNS_PASS=$SLOWDNS_PASS
EOF
  systemctl daemon-reload; systemctl enable --now zainu-slowdns 2>/dev/null || true
  ok "SlowDNS: NS=$SLOWDNS_NS pass=$SLOWDNS_PASS  (client: iodine -f -P $SLOWDNS_PASS $SLOWDNS_NS)"
}

#────────────────────────────── 9. Hysteria2 ────────────────────────────────
install_hysteria2(){
  step "[9/13] Hysteria2 (UDP $PORT_HY2)"
  bash <(curl -fsSL https://get.hy2.sh/) 2>>"$LOG" || wr "hysteria installer issue"
  HY2_PASS="$(rand_str 16)"
  cat > /etc/hysteria/config.yaml <<EOF
# ZAINU X BRAND Hysteria2
listen: :$PORT_HY2
tls:
  cert: $CERT_PATH
  key: $KEY_PATH
auth:
  type: password
  password: $HY2_PASS
masquerade:
  type: proxy
  proxy:
    url: https://$DOMAIN/
    rewriteHost: true
EOF
  systemctl enable --now hysteria-server 2>/dev/null || true
  ok "Hysteria2 UDP $PORT_HY2 pass=$HY2_PASS"
}

#────────────────────────────── 10. WireGuard ────────────────────────────────
install_wireguard(){
  step "[10/13] WireGuard (UDP $PORT_WG)"
  apt-get -y -qq install wireguard wireguard-tools 2>/dev/null || true
  WG_PRIV="$(wg genkey 2>/dev/null || echo PLACEHOLDER)"; WG_PUB="$(echo "$WG_PRIV" | wg pubkey 2>/dev/null || echo PLACEHOLDER)"
  WG_CP="$(wg genkey 2>/dev/null || echo PLACEHOLDER)"; WG_CPB="$(echo "$WG_CP" | wg pubkey 2>/dev/null || echo PLACEHOLDER)"
  cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.66.66.1/24
ListenPort = $PORT_WG
PrivateKey = $WG_PRIV
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
[Peer]
PublicKey = $WG_CPB
AllowedIPs = 10.66.66.2/32
EOF
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  systemctl enable --now wg-quick@wg0 2>/dev/null || true
  cat > /root/zainu-wg-client.conf <<EOF
[Interface]
Address = 10.66.66.2/24
PrivateKey = $WG_CP
DNS = 1.1.1.1
[Peer]
PublicKey = $WG_PUB
Endpoint = $PUBIP:$PORT_WG
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
  ok "WireGuard UDP $PORT_WG (/root/zainu-wg-client.conf)"
}

#────────────────────────────── 11. OpenVPN ─────────────────────────────────
install_openvpn(){
  step "[11/13] OpenVPN (UDP $PORT_OVPN)"
  apt-get -y -qq install openvpn easy-rsa 2>/dev/null || true
  make-cadir /etc/openvpn/easy-rsa 2>/dev/null || true
  cat > /etc/openvpn/server.conf <<EOF
# ZAINU X BRAND OpenVPN
port $PORT_OVPN
proto udp
dev tun
ca   /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key  /etc/openvpn/easy-rsa/pki/private/server.key
dh   /etc/openvpn/easy-rsa/pki/dh.pem
server 10.8.0.0 255.255.255.0
keepalive 10 120
persist-key
persist-tun
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
status /var/log/openvpn-status.log
verb 3
EOF
  wr "OpenVPN config at /etc/openvpn/server.conf — run easy-rsa then: systemctl enable --now openvpn@server"
  ok "OpenVPN base on UDP $PORT_OVPN"
}

#────────────────────────────── 12. Account system + welcome ────────────────
install_account_system(){
  step "[12/13] Account system (IP limit / GB limit / expiry) + brand welcome"

  # per-account login shell: brand banner + expiry/IP/GB enforcement
  cat > /usr/local/bin/zainu-shell <<'SHELL'
#!/usr/bin/env bash
# ZAINU X BRAND 😎 per-account login shell
U="${USER:-}"; DB="/etc/zainu/accounts.db"
[ -f "$DB" ] || exit 1
line="$(grep "^${U}:" "$DB" 2>/dev/null)" || exit 1
IFS=':' read -r u pw exp iplim gblim uid status created <<<"$line"
now=$(date +%s)
R='\033[1;31m';G='\033[1;32m';Y='\033[1;33m';C='\033[1;36m';M='\033[1;35m';W='\033[1;37m';K='\033[0m'
ban(){ echo -e "${C}╔══════════════════════════════════════════════╗${K}"
       echo -e "${C}║        ZAINU X BRAND 😎  PREMIUM VPN          ║${K}"
       echo -e "${C}╚══════════════════════════════════════════════╝${K}"; }
if [ "$status" != "active" ]; then ban; echo -e "${R}ACCOUNT LOCKED${K}"; exit 1; fi
if [ "$exp" != "0" ] && [ "$now" -gt "$exp" ]; then
  ban; echo -e "${R}ACCOUNT EXPIRED on $(date -d @$exp '+%Y-%m-%d')${K}"; exit 1; fi
# IP limit: count distinct source IPs currently connected for this user
cur_ips=$(who 2>/dev/null | awk -v u="$U" '$1==u{print $NF}' | sed 's/[(:].*//' | sort -u | grep -c . 2>/dev/null || echo 0)
if [ "$iplim" != "0" ] && [ "$cur_ips" -gt "$iplim" ]; then
  ban; echo -e "${R}IP LIMIT REACHED ($iplim max)${K}"; exit 1; fi
# GB used (iptables accounting chain ZAINU_<user>)
used_b=0
if iptables -L "ZAINU_${U}" -vxn >/dev/null 2>&1; then
  used_b=$(iptables -L "ZAINU_${U}" -vxn | awk '/RETURN/{s+=$2} END{print s+0}')
fi
used_gb=$(awk "BEGIN{printf \"%.2f\", ${used_b}/1073741824}")
if [ "$gblim" != "0" ] && awk "BEGIN{exit !(${used_b} > ${gblim}*1073741824)}"; then
  ban; echo -e "${R}GB LIMIT REACHED ($gblim GB)${K}"; exit 1; fi
ban
echo -e "${G} Account   :${K} $U"
echo -e "${G} IP limit  :${K} $iplim  (now: $cur_ips)"
echo -e "${G} Data      :${K} $used_gb GB / ${gblim} GB"
echo -e "${G} Expiry    :${K} $( [ "$exp" = "0" ] && echo 'unlimited' || date -d @$exp '+%Y-%m-%d %H:%M')"
echo -e "${M} Powered by ZAINU X BRAND 😎${K}"
echo
sleep infinity
SHELL
  chmod +x /usr/local/bin/zainu-shell

  # motd banner (connect-time "server msg")
  : > /etc/motd
  cat > /etc/profile.d/zz-zainu-welcome.sh <<EOF
#!/usr/bin/env bash
# ZAINU X BRAND 😎 — connect-time server message
if [[ -n "\${SSH_CONNECTION:-}" && "\${USER}" != "root" ]]; then
  echo -e "\033[1;36m╔══════════════════════════════════════════════╗\033[0m"
  echo -e "\033[1;36m║        ZAINU X BRAND 😎  PREMIUM VPN          ║\033[0m"
  echo -e "\033[1;36m╚══════════════════════════════════════════════╝\033[0m"
fi
EOF
  chmod +x /etc/profile.d/zz-zainu-welcome.sh

  # accounting + expiry cron (every 2 min)
  cat > /usr/local/bin/zainu-cron.sh <<'CRON'
#!/usr/bin/env bash
# ZAINU X BRAND — enforce expiry + GB limits
DB="/etc/zainu/accounts.db"; [ -f "$DB" ] || exit 0
now=$(date +%s)
while IFS=':' read -r u pw exp iplim gblim uid status created; do
  [ -z "$u" ] && continue
  # expiry
  if [ "$exp" != "0" ] && [ "$now" -gt "$exp" ]; then
    if [ "$status" = "active" ]; then passwd -l "$u" 2>/dev/null || true
      sed -i "s/^${u}:\(.*\):\(.*\):\(.*\):\(.*\):\(.*\):active:/\0/; s/^${u}:\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):active:/\u:\pw:\exp:\iplim:\gblim:\uid:expired:/" "$DB" 2>/dev/null
    fi; continue; fi
  # GB
  used_b=0
  if iptables -L "ZAINU_${u}" -vxn >/dev/null 2>&1; then
    used_b=$(iptables -L "ZAINU_${u}" -vxn | awk '/RETURN/{s+=$2} END{print s+0}')
  fi
  if [ "$gblim" != "0" ] && awk "BEGIN{exit !(${used_b} > ${gblim}*1073741824)}"; then
    if [ "$status" = "active" ]; then passwd -l "$u" 2>/dev/null || true
      sed -i "s/^${u}:/LOCK_${u}:/" "$DB" 2>/dev/null
    fi
  fi
done < "$DB"
CRON
  chmod +x /usr/local/bin/zainu-cron.sh
  ( crontab -l 2>/dev/null; echo "*/2 * * * * /usr/local/bin/zainu-cron.sh" ) | crontab -
  touch "$DB"
  ok "Account system ready (shell=zainu-shell, cron=enforce, db=$DB)"
}

#────────────────────────────── 13. Firewall + link gen ──────────────────────
setup_firewall_links(){
  step "[13/13] UFW firewall (all protocols) + link generation"
  apt-get -y -qq install ufw 2>/dev/null || true
  ufw --force reset >/dev/null; ufw default deny incoming; ufw default allow outgoing
  for p in "$PORT_SSH/tcp:$TAG-SSH" "$PORT_DROP/tcp:$TAG-Dropbear" "$PORT_SSL/tcp:$TAG-SSL" \
           "$PORT_WS_HTTP/tcp:$TAG-WS-nonTLS" "$PORT_WS_TLS/tcp:$TAG-WS-TLS" \
           "$PORT_UDP/udp:$TAG-UDP" "$PORT_VMESS_TCP/tcp:$TAG-VMess-TCP" \
           "$PORT_REALITY/tcp:$TAG-Reality" "$PORT_GRPC/tcp:$TAG-gRPC" "$PORT_SS/tcp:$TAG-SS" \
           "$PORT_SLOWDNS/udp:$TAG-SlowDNS" "$PORT_HY2/udp:$TAG-HY2" \
           "$PORT_WG/udp:$TAG-WG" "$PORT_OVPN/udp:$TAG-OVPN"; do
    port="${p%%/*}"; proto="${p#*/}"; cmt="${p##*:}"; ufw allow "$port/$proto" comment "$cmt" >/dev/null
  done
  ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 443/udp
  ufw limit "$PORT_SSH"/tcp; ufw --force enable

  # generate xray links
  local vmess_tls="{\"v\":\"2\",\"ps\":\"$TAG-VMess-WS-TLS\",\"add\":\"$DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"$P_VMESS\",\"tls\":\"tls\",\"sni\":\"$DOMAIN\"}"
  VMESS_WS_TLS="vmess://$(echo -n "$vmess_tls" | base64 -w0)"
  local vmess_cf="{\"v\":\"2\",\"ps\":\"$TAG-VMess-WS-CF\",\"add\":\"$CF_HOST\",\"port\":\"80\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"$P_VMESS\",\"tls\":\"\"}"
  VMESS_WS_CF="vmess://$(echo -n "$vmess_cf" | base64 -w0)"
  local vmess_tcp="{\"v\":\"2\",\"ps\":\"$TAG-VMess-TCP\",\"add\":\"$DOMAIN\",\"port\":\"$PORT_VMESS_TCP\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"tcp\",\"tls\":\"\"}"
  VMESS_TCP="vmess://$(echo -n "$vmess_tcp" | base64 -w0)"
  local pv=$(printf '%s' "$P_VLESS"|sed 's#/#%2F#g'); local pt=$(printf '%s' "$P_TROJAN"|sed 's#/#%2F#g')
  VLESS_WS_TLS="vless://$UUID@$DOMAIN:443?security=tls&type=ws&path=$pv&host=$DOMAIN&sni=$DOMAIN#$TAG-VLESS-WS-TLS"
  VLESS_WS_CF="vless://$UUID@$CF_HOST:80?type=ws&path=$pv&host=$CF_HOST#$TAG-VLESS-WS-CF"
  VLESS_REALITY="vless://$UUID@$DOMAIN:$PORT_REALITY?security=reality&sni=$DOMAIN&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_SID&type=tcp&flow=xtls-rprx-vision#$TAG-VLESS-Reality"
  TROJAN_WS_TLS="trojan://$TROJAN_PASS@$DOMAIN:443?security=tls&type=ws&path=$pt&host=$DOMAIN&sni=$DOMAIN#$TAG-Trojan-WS"
  TROJAN_GRPC="trojan://$TROJAN_PASS@$DOMAIN:$PORT_GRPC?security=tls&type=grpc&serviceName=trojan-grpc&sni=$DOMAIN#$TAG-Trojan-gRPC"
  local ssb64="$(printf 'aes-256-gcm:%s' "$SS_PASS" | base64 -w0)"
  SS_LINK="ss://$ssb64@$DOMAIN:$PORT_SS#$TAG-Shadowsocks"
  HY2_LINK="hysteria2://$HY2_PASS@$DOMAIN:$PORT_HY2/?sni=$DOMAIN&insecure=0#$TAG-Hysteria2"
  ok "UFW + links ready"
}

install_menu_cmd(){
  # install the script itself + 'zainu' command
  cp "$0" /usr/local/share/zainu-vpn.sh 2>/dev/null || true
  chmod +x /usr/local/share/zainu-vpn.sh
  ln -sf /usr/local/share/zainu-vpn.sh /usr/local/bin/zainu
  # branded nginx index
  cat > /var/www/html/index.html <<EOF
<!doctype html><title>ZAINU X BRAND</title>
<body style="background:#0b0f1a;color:#5ff;font-family:monospace;text-align:center;padding-top:15vh">
<h1 style="font-size:3em;color:#5ff;text-shadow:0 0 20px #0ff">ZAINU X BRAND 😎</h1>
<h2 style="color:#9ff">PREMIUM VPN</h2><p>All Protocols • Real TLS • Cloudflare</p>
</body></html>
EOF
}

do_install(){
  preflight; get_inputs
  install_deps; install_ssh_dropbear; install_ssl; install_cert; install_websocket
  install_udp; install_xray; install_slowdns; install_hysteria2; install_wireguard
  install_openvpn; install_account_system; setup_firewall_links; install_menu_cmd
  echo "$VER $(date +%s)" > "$MARKER"
  final_report
}

final_report(){
  hr; brand_banner; hr
  cat <<EOF | tee -a "$LOG"

${M}━━ CONNECT-TIME SERVER MESSAGE${K}
  Branded banner shows on every SSH/login: "ZAINU X BRAND 😎 — PREMIUM VPN"
  Per-account shell enforces IP limit / GB limit / expiry.

${G}━━ PORTS / PROTOCOLS${K}
  SSH $PORT_SSH • Dropbear $PORT_DROP • SSL $PORT_SSL • WS $PORT_WS_HTTP/$PORT_WS_TLS
  UDP $PORT_UDP • VMess-TCP $PORT_VMESS_TCP • Reality $PORT_REALITY • gRPC $PORT_GRPC
  SS $PORT_SS • SlowDNS $PORT_SLOWDNS • Hysteria2 $PORT_HY2 • WG $PORT_WG • OVPN $PORT_OVPN

${C}━━ XRAY LINKS${K}
  VMess WS-TLS : $VMESS_WS_TLS
  VMess WS-CF  : $VMESS_WS_CF
  VMess TCP    : $VMESS_TCP
  VLESS WS-TLS : $VLESS_WS_TLS
  VLESS WS-CF  : $VLESS_WS_CF
  VLESS Reality: $VLESS_REALITY
  Trojan WS    : $TROJAN_WS_TLS
  Trojan gRPC  : $TROJAN_GRPC
  Shadowsocks  : $SS_LINK
  Hysteria2    : $HY2_LINK
  WireGuard    : /root/zainu-wg-client.conf
  SlowDNS cmd  : iodine -f -P $SLOWDNS_PASS $SLOWDNS_NS

${Y}━━ MANAGE ACCOUNTS${K}
  Type ${G}zainu${K} (or re-run this script) → colorful menu:
  Create account (asks: IP limit, GB limit, expiry), List, Delete, Renew, Traffic.

${M}━━ NEXT${K}
  1. ${G}zainu${K}  →  create your accounts (IP/GB/expiry prompts)
  2. share the generated links/accounts
  3. sudo reboot

${G}━━ ALL DONE. Powered by $BRAND 😎 ━━${K}
EOF
  hr
}

#────────────────────────────── ACCOUNT MANAGEMENT ────────────────────────────
acc_create(){
  step "CREATE ACCOUNT  (asks: IP limit, GB limit, expiry)"
  mkdir -p "$ZDIR"; touch "$DB"
  read -r -p "Username: " u; [[ -n "$u" ]] || { er "no username"; return; }
  grep -q "^${u}:" "$DB" 2>/dev/null && { er "user exists"; return; }
  read -r -p "Password [random]: " p; p="${p:-$(rand_str 14)}"
  read -r -p "IP limit (max simultaneous IPs, 0=unlimited): " iplim; iplim="${iplim:-1}"
  read -r -p "GB limit (0=unlimited): " gblim; gblim="${gblim:-0}"
  read -r -p "Expiry days (0=unlimited): " days; days="${days:-30}"
  exp=0; [[ "$days" != "0" ]] && exp=$(($(date +%s)+days*86400))
  # create system user with zainu-shell
  if ! id -u "$u" >/dev/null 2>&1; then
    useradd -m -s /usr/local/bin/zainu-shell "$u" 2>/dev/null || { er "useradd failed"; return; }
  fi
  echo "$u:$p" | chpasswd
  uid=$(id -u "$u")
  # iptables accounting chain
  iptables -N "ZAINU_${u}" 2>/dev/null || true
  iptables -C OUTPUT -m owner --uid-owner "$uid" -j "ZAINU_${u}" 2>/dev/null || \
    iptables -A OUTPUT -m owner --uid-owner "$uid" -j "ZAINU_${u}" 2>/dev/null || true
  iptables -C "ZAINU_${u}" -j RETURN 2>/dev/null || iptables -A "ZAINU_${u}" -j RETURN 2>/dev/null || true
  echo "$u:$p:$exp:$iplim:$gblim:$uid:active:$(date +%s)" >> "$DB"
  ok "Account '$u' created"
  echo -e "${G}  user:${K} $u  ${G}pass:${K} $p  ${G}IP:${K} $iplim  ${G}GB:${K} $gblim  ${G}expiry:${K} $( [ $exp = 0 ] && echo unlimited || date -d @$exp '+%Y-%m-%d')"
  echo -e "${C}  SSH connect:${K}  ssh -p $PORT_SSH $u@$PUBIP   (or Dropbear $PORT_DROP, SSL $PORT_SSL)"
}

acc_list(){
  step "ACCOUNTS"
  [[ -f "$DB" ]] || { wr "No accounts yet. Create one first."; return; }
  printf "${M}%-15s %-6s %-6s %-8s %-12s %-10s${K}\n" "USER" "IPLIM" "GBLIM" "STATUS" "EXPIRY" "USED(GB)"
  while IFS=':' read -r u pw exp iplim gblim uid status created; do
    [ -z "$u" ] && continue
    used_b=0; iptables -L "ZAINU_${u}" -vxn >/dev/null 2>&1 && used_b=$(iptables -L "ZAINU_${u}" -vxn | awk '/RETURN/{s+=$2} END{print s+0}')
    used_gb=$(awk "BEGIN{printf \"%.2f\", ${used_b}/1073741824}")
    exps=$([ "$exp" = "0" ] && echo "unlimited" || date -d @$exp '+%Y-%m-%d')
    printf "%-15s %-6s %-6s %-8s %-12s %-10s\n" "$u" "$iplim" "$gblim" "$status" "$exps" "$used_gb"
  done < "$DB"
}

acc_delete(){
  read -r -p "Delete username: " u; [[ -n "$u" ]] || return
  iptables -D OUTPUT -m owner --uid-owner "$(id -u "$u" 2>/dev/null)" -j "ZAINU_${u}" 2>/dev/null || true
  iptables -F "ZAINU_${u}" 2>/dev/null || true; iptables -X "ZAINU_${u}" 2>/dev/null || true
  sed -i "/^${u}:/d" "$DB"; userdel -r "$u" 2>/dev/null || true
  ok "Deleted '$u'"
}

acc_renew(){
  read -r -p "Renew username: " u; [[ -n "$u" ]] || return
  grep -q "^${u}:" "$DB" || { er "not found"; return; }
  read -r -p "Add days (0=unlimited): " days; days="${days:-30}"
  read -r -p "Add GB (blank=keep): " addgb
  line="$(grep "^${u}:" "$DB")"; IFS=':' read -r _ p exp iplim gblim uid status cr <<<"$line"
  [ "$exp" = "0" ] && exp=$(date +%s)
  [ "$days" != "0" ] && exp=$((exp+days*86400)) || { [ "$days" = "0" ] && exp=0; }
  passwd -u "$u" 2>/dev/null || true
  sed -i "s/^${u}:.*:.*/${u}:${p}:${exp}:${iplim}:${gblim}:${uid}:active:${cr}/" "$DB"
  ok "Renewed '$u' → expiry $( [ $exp = 0 ] && echo unlimited || date -d @$exp '+%Y-%m-%d')"
}

acc_traffic(){
  step "TRAFFIC"
  while IFS=':' read -r u pw exp iplim gblim uid status created; do
    [ -z "$u" ] && continue
    used_b=0; iptables -L "ZAINU_${u}" -vxn >/dev/null 2>&1 && used_b=$(iptables -L "ZAINU_${u}" -vxn | awk '/RETURN/{s+=$2} END{print s+0}')
    used_gb=$(awk "BEGIN{printf \"%.2f\", ${used_b}/1073741824}")
    echo -e "${C}$u${K}: ${used_gb} GB / ${gblim} GB (status: $status)"
  done < "$DB"
}

restart_all(){
  step "Restarting services"
  for s in ssh dropbear stunnel4 nginx xray zainu-udpgw zainu-slowdns hysteria-server wg-quick@wg0; do
    systemctl restart "$s" 2>/dev/null && ok "$s" || wr "$s skip"
  done
}

sys_info(){
  step "SYSTEM INFO"
  echo -e "${C}Brand${K}   : $BRAND v$VER"
  echo -e "${C}OS${K}      : $(. /etc/os-release; echo "$PRETTY_NAME")"
  echo -e "${C}Uptime${K} : $(uptime -p 2>/dev/null || uptime)"
  echo -e "${C}IP${K}      : $(get_pubip)"
  echo -e "${C}Load${K}    : $(cat /proc/loadavg)"
  echo -e "${C}RAM${K}     : $(free -h | awk '/Mem:/{print $3"/"$2}')"
  echo -e "${C}Accounts${K}: $(grep -c ':' "$DB" 2>/dev/null || echo 0)"
}

#────────────────────────────── Colorful Menu ─────────────────────────────────
menu(){
  while true; do
    clear 2>/dev/null || true
    brand_banner
    echo -e "${G}Server:${K} $(hostname)  ${Y}IP:${K} $(get_pubip)  ${M}Accounts:${K} $(grep -c ':' "$DB" 2>/dev/null || echo 0)"
    echo -e "${M}════════════════════════════════════════════════════════════${K}"
    echo -e "  ${C}1${K}) ${G}Create Account${K}   (IP limit / GB limit / expiry)"
    echo -e "  ${C}2${K}) ${G}List Accounts${K}"
    echo -e "  ${C}3${K}) ${G}Delete Account${K}"
    echo -e "  ${C}4${K}) ${G}Renew / Extend Account${K}"
    echo -e "  ${C}5${K}) ${G}Traffic Usage${K}"
    echo -e "  ${C}6${K}) ${G}Restart All Services${K}"
    echo -e "  ${C}7${K}) ${G}System Info${K}"
    echo -e "  ${C}8${K}) ${G}Show VPN Links${K}"
    echo -e "  ${C}0${K}) ${R}Exit${K}"
    echo -e "${M}════════════════════════════════════════════════════════════${K}"
    read -r -p "Select [0-8]: " c
    case "$c" in
      1) acc_create ;;
      2) acc_list ;;
      3) acc_delete ;;
      4) acc_renew ;;
      5) acc_traffic ;;
      6) restart_all ;;
      7) sys_info ;;
      8) final_report 2>/dev/null || cat "$LOG" ;;
      0|"") echo -e "${M}Bye! Powered by $BRAND 😎${K}"; break ;;
      *) wr "invalid choice" ;;
    esac
    echo; read -r -p "Press Enter to continue..." _
  done
}

#────────────────────────────── Uninstall ────────────────────────────────────
do_uninstall(){
  hr; echo -e "${R}Uninstalling $BRAND ...${K}"; hr
  systemctl disable --now xray zainu-udpgw zainu-slowdns hysteria-server wg-quick@wg0 2>/dev/null || true
  apt-get -y remove --purge xray dropbear stunnel4 nginx iodine hysteria-server wireguard openvpn 2>/dev/null || true
  rm -rf /etc/zainu /usr/local/bin/zainu* /etc/systemd/system/zainu-*.service /usr/local/share/zainu-vpn.sh 2>/dev/null || true
  ( crontab -l 2>/dev/null | grep -v zainu-cron ) | crontab - 2>/dev/null || true
  systemctl daemon-reload
  echo -e "${G}Uninstalled.${K}"; exit 0
}

#────────────────────────────── Main ──────────────────────────────────────────
main(){
  case "$ACTION" in
    uninstall) do_uninstall ;;
    install) PUBIP="$(get_pubip)"; do_install ;;
    create)  PUBIP="$(get_pubip)"; acc_create ;;
    list)    PUBIP="$(get_pubip)"; acc_list ;;
    menu)    PUBIP="$(get_pubip)"; menu ;;
    auto)
      PUBIP="$(get_pubip)"
      if is_installed; then menu
      else do_install; fi
      ;;
  esac
}
main "$@"
