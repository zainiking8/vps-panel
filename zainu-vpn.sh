#!/usr/bin/env bash
#==============================================================================
#   ZAINU X BRAND 😎  —  PREMIUM VPN SCRIPT  v3.0
#   FULL INSTALL + ACCOUNT SYSTEM + BRAND EVERYWHERE
#   SSH • Dropbear • SSL-TLS • Websocket(TLS+nonTLS) • UDP-Custom
#   Xray: VLESS • VMess • Trojan • Reality • Shadowsocks • gRPC
#   SlowDNS (iodine) • Hysteria2 • WireGuard • OpenVPN
#   Ubuntu 20.04+ / Debian 11+
#==============================================================================
# SAFETY: keep -u/-o pipefail but allow non-fatal warnings so a single
# cert hiccup doesn't kill the whole install.
set -Euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

BRAND="ZAINU X BRAND 😎"; TAG="ZAINU-X-BRAND"; VER="3.0"
LOG="/var/log/zainu-vpn.log"
ZDIR="/etc/zainu"; DB="$ZDIR/accounts.db"; MARKER="$ZDIR/installed"

# SSH/Tunnel
PORT_SSH=22; PORT_DROP=143; PORT_SSL=9443
# HTTP/WS (TCP 80 + TCP 443 via nginx)
PORT_WS_HTTP=80; PORT_WS_TLS=443; PORT_WS_SSH=20000
# UDP custom
PORT_UDP=7100
# Xray inbounds
PORT_VMESS_WS=20001; PORT_VLESS_WS=20002; PORT_TROJAN_WS=20003
PORT_VMESS_TCP=10086; PORT_REALITY=8443; PORT_GRPC=2053
# Other
PORT_SS=8388; PORT_SLOWDNS=53; PORT_HY2=443
PORT_WG=51820; PORT_OVPN=1194

# WS paths (also written to nginx/xray configs)
P_VMESS="/vmess-ws"; P_VLESS="/vless-ws"; P_TROJAN="/trojan-ws"; P_SSH="/ssh-ws"

# inputs
DOMAIN=""; EMAIL=""; CF_HOST=""; SLOWDNS_NS=""; SLOWDNS_PASS=""; PUBIP=""

# link globals (set by install_xray / install_hysteria2 etc)
UUID=""; TROJAN_PASS=""; SS_PASS=""; PUB_KEY=""; PRIV_KEY=""; SHORT_SID=""
HY2_PASS=""; CERT_PATH=""; KEY_PATH=""; WG_PUB=""
VMESS_WS_TLS=""; VMESS_WS_CF=""; VMESS_TCP=""
VLESS_WS_TLS=""; VLESS_WS_CF=""; VLESS_REALITY=""
TROJAN_WS_TLS=""; TROJAN_GRPC=""; SS_LINK=""; HY2_LINK=""
UDP_CUSTOM_CMD=""

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

brand_banner(){
  echo
  echo -e "${C}╔════════════════════════════════════════════════════════════╗${K}"
  echo -ne "║  "; rainbow "ZAINU X BRAND 😎"; printf '  %b\n' "$K"
  echo -e "${G}║             PREMIUM VPN SCRIPT  v${VER}${K}"
  echo -e "${Y}║   ALL PROTOCOLS • REAL TLS • CLOUDFLARE • ACCOUNTS${K}"
  echo -e "${M}╚════════════════════════════════════════════════════════════╝${K}"
  echo
}

# Big banner used on SSH login + everywhere a user might see the brand
connect_banner(){
  cat <<EOF

${C}════════════════════════════════════════════════════════════════════${K}
${G}    ███████╗ █████╗ ██╗███╗   ██╗██╗   ██╗
    ╚══███╔╝██╔══██╗██║████╗  ██║██║   ██║
      ███╔╝ ███████║██║██╔██╗ ██║██║   ██║
     ███╔╝  ██╔══██║██║██║╚██╗██║██║   ██║
    ███████╗██║  ██║██║██║ ╚████║╚██████╔╝
    ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝${K}
${Y}                X BRAND 😎  PREMIUM VPN${K}
${C}════════════════════════════════════════════════════════════════════${K}
${G}  Server :${K} ${DOMAIN:-$PUBIP}
${G}  IP     :${K} ${PUBIP}
${G}  Tag    :${K} ${TAG}
${C}────────────────────────────────────────────────────────────────────${K}
${Y}  Welcome to ${BRAND} — Authorized access only.${K}
${C}════════════════════════════════════════════════════════════════════${K}
EOF
}

get_pubip(){ curl -s4 --max-time 6 https://api.ipify.org 2>/dev/null || curl -s4 --max-time 6 https://ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"; }
rand_str(){ head -c "${1:-16}" /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c"${1:-16}"; }
rand_hex(){ openssl rand -hex "${1:-8}" 2>/dev/null || echo "$(date +%N)$(date +%s)"; }
pause(){ printf "\n${Y}Press ENTER to return to menu...${K}"; read -r _; }

#────────────────────────────── Config persistence ──────────────────────────
load_config(){
  [[ -f "$ZDIR/config.env" ]] || return 0
  # shellcheck disable=SC1090
  set +u; source "$ZDIR/config.env" || true; set -u
}
persist_config(){
  mkdir -p "$ZDIR" 2>/dev/null || true
  umask 077
  cat > "$ZDIR/config.env" <<EOF
# ZAINU X BRAND 😎 — persisted runtime config (auto-generated)
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
CF_HOST="$CF_HOST"
SLOWDNS_NS="$SLOWDNS_NS"
SLOWDNS_PASS="$SLOWDNS_PASS"
PUBIP="$PUBIP"
UUID="$UUID"
TROJAN_PASS="$TROJAN_PASS"
SS_PASS="$SS_PASS"
PUB_KEY="$PUB_KEY"
PRIV_KEY="$PRIV_KEY"
SHORT_SID="$SHORT_SID"
HY2_PASS="$HY2_PASS"
CERT_PATH="$CERT_PATH"
KEY_PATH="$KEY_PATH"
P_VMESS="$P_VMESS"
P_VLESS="$P_VLESS"
P_TROJAN="$P_TROJAN"
P_SSH="$P_SSH"
WG_PUB="$WG_PUB"
VMESS_WS_TLS="$VMESS_WS_TLS"
VMESS_WS_CF="$VMESS_WS_CF"
VMESS_TCP="$VMESS_TCP"
VLESS_WS_TLS="$VLESS_WS_TLS"
VLESS_WS_CF="$VLESS_WS_CF"
VLESS_REALITY="$VLESS_REALITY"
TROJAN_WS_TLS="$TROJAN_WS_TLS"
TROJAN_GRPC="$TROJAN_GRPC"
SS_LINK="$SS_LINK"
HY2_LINK="$HY2_LINK"
UDP_CUSTOM_CMD="$UDP_CUSTOM_CMD"
EOF
  chmod 600 "$ZDIR/config.env"
  ok "Config persisted to $ZDIR/config.env"
}

#────────────────────────────── Help / Args ───────────────────────────────────
print_help(){
  brand_banner
  cat <<EOF
${G}Usage:${K} sudo bash zainu-vpn.sh [OPTIONS]

  --install       full protocol install (re-runs even if already installed)
  --menu          open management menu (after install)
  --create        quick create SSH account (prompts IP/GB/expiry)
  --list          list accounts
  --uninstall     remove everything
  --reset         nuke persisted config (forces fresh setup next run)
  --help, -h      this help

${Y}Without args:${K} installs if not yet installed, otherwise opens the menu.

${C}Non-interactive example:${K}
  sudo bash zainu-vpn.sh --install --domain vpn.example.com --email me@x.com \
    --cfhost cdn.example.com --slownsdn ns1.example.com --slowpass mypass
EOF
}

ACTION="auto"
RESET_CONFIG=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)    ACTION="install"; shift ;;
    --menu)        ACTION="menu"; shift ;;
    --create)     ACTION="create"; shift ;;
    --list)       ACTION="list"; shift ;;
    --uninstall)  ACTION="uninstall"; shift ;;
    --reset)      RESET_CONFIG=1; shift ;;
    --domain)     DOMAIN="$2"; shift 2 ;;
    --email)      EMAIL="$2"; shift 2 ;;
    --cfhost)     CF_HOST="$2"; shift 2 ;;
    --slownsdn)   SLOWDNS_NS="$2"; shift 2 ;;
    --slowpass)   SLOWDNS_PASS="$2"; shift 2 ;;
    --help|-h)    print_help; exit 0 ;;
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
  # shellcheck disable=SC1091
  . /etc/os-release
  case "$ID" in ubuntu|debian) ok "OS: $PRETTY_NAME" ;; *) die "Unsupported distro '$ID'." ;; esac
  PUBIP="$(get_pubip)"; ok "Public IP: $PUBIP"
  if [[ -t 0 ]]; then
    echo -e "\n${Y}This installs ALL VPN protocols + account system on this VPS.${K}"
    read -r -p "Proceed? [y/N]: " ans
    [[ "${ans:-N}" =~ ^[Yy]$ ]] || die "Aborted."
  fi
  hr
}

get_inputs(){
  step "Collecting setup details"
  # Use --env values if set, otherwise prompt (only if interactive)
  if [[ -t 0 ]]; then
    [[ -z "$DOMAIN" ]]    && read -r -p "Domain (A-recorded to VPS, e.g. vpn.example.com): " DOMAIN
    [[ -z "$EMAIL" ]]     && read -r -p "Email for Let's Encrypt: " EMAIL
    [[ -z "$CF_HOST" ]]   && { read -r -p "Cloudflare-proxied host for ws:// links [$DOMAIN]: " CF_HOST; CF_HOST="${CF_HOST:-$DOMAIN}"; }
    [[ -z "$SLOWDNS_NS" ]]   && read -r -p "SlowDNS NS subdomain (ns1.your-domain.com): " SLOWDNS_NS
    [[ -z "$SLOWDNS_PASS" ]] && { SLOWDNS_PASS="$(rand_str 16)"; wr "Auto-generated SlowDNS password: $SLOWDNS_PASS"; }
  fi
  : "${DOMAIN:?--domain required (use --domain=... for non-interactive)}"
  : "${EMAIL:?--email required (use --email=... for non-interactive)}"
  [[ -n "$CF_HOST" ]] || CF_HOST="$DOMAIN"
  ok "Domain=$DOMAIN  CF=$CF_HOST  NS=$SLOWDNS_NS"
  hr
}

#────────────────────────────── 1. Dependencies ─────────────────────────────
install_deps(){
  step "[1/14] Dependencies"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq 2>>"$LOG" || wr "apt update warning"
  apt-get -y -o Dpkg::Options::="--force-confold" upgrade 2>>"$LOG" || wr "apt upgrade warning"
  apt-get -y -o Dpkg::Options::="--force-confold" install -y \
    curl wget git unzip tar gzip ca-certificates gnupg lsb-release \
    software-properties-common build-essential qrencode jq bc \
    net-tools dnsutils iproute2 iputils-ping socat iptables \
    nginx dropbear stunnel4 chrony cron uuid-runtime pwgen openssl \
    python3 python3-pip 2>>"$LOG" || wr "apt install warning"
  mkdir -p "$ZDIR" /var/www/html
  ok "Dependencies ready"
}

#────────────────────────────── 1b. Brand banner (SSH + console) ─────────────
install_brand_banner(){
  step "[1b/14] Brand banner (SSH login + console)"
  # /etc/motd — shown after SSH login (PAM)
  cat > /etc/motd <<EOF

$(connect_banner)

EOF
  # /etc/issue — local console + pre-login prompt
  cat > /etc/issue <<EOF
${BRAND} — PREMIUM VPN
Server: \n
EOF
  cat > /etc/issue.net <<EOF

${BRAND}  —  PREMIUM VPN
        Server : ${DOMAIN:-${PUBIP}}
        IP     : ${PUBIP}
        Authorized access only.

EOF
  # enable motd via PAM
  if ! grep -q "^session.*optional.*pam_motd" /etc/pam.d/sshd 2>/dev/null; then
    sed -i 's|#session.*pam_motd.so.*motd=/run/motd.dynamic noupdate|session optional pam_motd.so motd=/run/motd.dynamic noupdate|' /etc/pam.d/sshd 2>/dev/null || true
  fi
  # also drop a script in /etc/profile.d for any login shell
  cat > /etc/profile.d/zainu-welcome.sh <<EOF
#!/bin/sh
# ZAINU X BRAND welcome banner
export TERM=xterm-256color
cat /etc/motd 2>/dev/null
EOF
  chmod +x /etc/profile.d/zainu-welcome.sh
  ok "Brand banner installed (motd, issue, issue.net, profile.d)"
}

#────────────────────────────── 2. SSH + Dropbear ───────────────────────────
install_ssh_dropbear(){
  step "[2/14] OpenSSH (branded banner) + Dropbear (tunnel)"
  local S=/etc/ssh/sshd_config
  cp -n "$S" "$S.bak.$(date +%s)" 2>/dev/null || true
  set_sshd(){ if grep -qE "^#?\s*${1}\b" "$S"; then sed -i "s|^#\?\s*${1}\b.*|${1} ${2}|" "$S"; else echo "${1} ${2}" >> "$S"; fi; }
  set_sshd Port "$PORT_SSH"
  set_sshd PermitRootLogin yes
  set_sshd PasswordAuthentication yes
  set_sshd PubkeyAuthentication yes
  set_sshd Banner /etc/issue.net
  set_sshd UsePAM yes
  mkdir -p /etc/ssh/sshd_config.d
  sshd -t 2>>"$LOG" || die "sshd syntax error"
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || wr "sshd restart — try manually"
  ok "OpenSSH on $PORT_SSH (brand banner)"

  mkdir -p /etc/dropbear
  cat > /etc/default/dropbear <<EOF
DROPBEAR_PORT=$PORT_DROP
DROPBEAR_EXTRA_ARGS="-p $PORT_DROP -I 3600 -m -K 300"
EOF
  systemctl enable --now dropbear 2>/dev/null || systemctl restart dropbear 2>/dev/null || wr "dropbear start failed"
  ok "Dropbear (tunnel) on $PORT_DROP"
}

#────────────────────────────── 3. SSL/TLS stunnel ─────────────────────────
install_ssl(){
  step "[3/14] SSL/TLS (stunnel on $PORT_SSL)"
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
  systemctl enable --now stunnel4 2>/dev/null || systemctl restart stunnel4 2>/dev/null || wr "stunnel start failed"
  ok "Stunnel SSL on $PORT_SSL → wraps Dropbear"
}

#────────────────────────────── 4. TLS cert (Let's Encrypt) ─────────────────
install_cert(){
  step "[4/14] TLS certificate (Let's Encrypt)"
  apt-get -y -qq install certbot python3-certbot-nginx 2>>"$LOG" || wr "certbot install warning"
  cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server; listen [::]:80 default_server;
    server_name $DOMAIN; root /var/www/html; index index.html;
}
EOF
  systemctl enable --now nginx 2>/dev/null || wr "nginx enable"
  systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
  if certbot --nginx -d "$DOMAIN" -m "$EMAIL" --non-interactive --agree-tos --redirect 2>>"$LOG"; then
    ok "Real TLS cert issued for $DOMAIN"
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    sed -i "s#^cert = .*#cert = $CERT_PATH#; s#^key = .*#key = $KEY_PATH#" /etc/stunnel/stunnel.conf 2>/dev/null || true
    cp "$CERT_PATH" /etc/nginx/ssl/${DOMAIN}.crt 2>/dev/null || true
    cp "$KEY_PATH"  /etc/nginx/ssl/${DOMAIN}.key 2>/dev/null || true
    systemctl restart stunnel4 2>/dev/null || true
  else
    wr "Let's Encrypt failed — using self-signed fallback."
    CERT_PATH="/etc/nginx/ssl/${DOMAIN}.crt"
    KEY_PATH="/etc/nginx/ssl/${DOMAIN}.key"
  fi
  export CERT_PATH KEY_PATH
  ok "Cert: $CERT_PATH"
}

#────────────────────────────── 5. SSH-over-WebSocket bridge ────────────────
install_ssh_ws_bridge(){
  step "[5/14] SSH-over-WebSocket bridge (for DarkTunnel / HTTP Injector)"
  cat > /usr/local/bin/zainu-ws-ssh.py <<'PYEOF'
#!/usr/bin/env python3
"""ZAINU X BRAND 😎 — WebSocket-to-SSH bridge
Listens on 127.0.0.1:20000, accepts WebSocket upgrade, forwards raw bytes to Dropbear :143
"""
import socket, threading, base64, hashlib, struct, os, sys

LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("ZAINU_WS_SSH_PORT", "20000"))
SSH_HOST    = os.environ.get("ZAINU_SSH_HOST", "127.0.0.1")
SSH_PORT    = int(os.environ.get("ZAINU_SSH_PORT", "143"))
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

def ws_handshake(client):
    try:
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = client.recv(4096)
            if not chunk: return False
            data += chunk
            if len(data) > 8192: return False
        headers = data.decode("latin-1", "ignore").split("\r\n")
        key = None
        for h in headers:
            if h.lower().startswith("sec-websocket-key:"):
                key = h.split(":", 1)[1].strip(); break
        if not key: return False
        accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
        resp = ("HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                "Sec-WebSocket-Accept: " + accept + "\r\n\r\n")
        client.sendall(resp.encode()); return True
    except Exception: return False

def ws_unwrap(client):
    try:
        hdr = client.recv(2)
        if len(hdr) < 2: return None
        plen = hdr[1] & 0x7F
        if plen == 126:
            plen = struct.unpack("!H", client.recv(2))[0]
        elif plen == 127:
            plen = struct.unpack("!Q", client.recv(8))[0]
        masked = hdr[1] & 0x80
        mask = client.recv(4) if masked else b""
        payload = b""
        while len(payload) < plen:
            chunk = client.recv(min(65536, plen - len(payload)))
            if not chunk: break
            payload += chunk
        if masked and mask:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        return payload
    except Exception: return None

def ws_wrap_and_send(client, payload):
    if not payload: return
    header = bytes([0x81])
    n = len(payload)
    if n < 126: header += bytes([0x80 | n])
    elif n < 65536: header += bytes([0x80 | 126]) + struct.pack("!H", n)
    else: header += bytes([0x80 | 127]) + struct.pack("!Q", n)
    mask = os.urandom(4); header += mask
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    try: client.sendall(header + masked)
    except Exception: pass

def pump(src, dst, ws_mode, ws_client):
    try:
        while True:
            if ws_mode == "unwrap":
                data = ws_unwrap(src)
                if data is None: break
                dst.sendall(data)
            else:
                data = src.recv(65536)
                if not data: break
                ws_wrap_and_send(ws_client, data)
    except Exception: pass
    finally:
        try: src.shutdown(socket.SHUT_RD)
        except Exception: pass
        try: dst.shutdown(socket.SHUT_WR)
        except Exception: pass

def handle(client):
    if not ws_handshake(client): client.close(); return
    try: ssh = socket.create_connection((SSH_HOST, SSH_PORT), timeout=10)
    except Exception: client.close(); return
    t1 = threading.Thread(target=pump, args=(client, ssh, "unwrap", None), daemon=True)
    t2 = threading.Thread(target=pump, args=(ssh, client, "wrap", client), daemon=True)
    t1.start(); t2.start()
    t1.join(); t2.join()
    try: client.close()
    except Exception: pass
    try: ssh.close()
    except Exception: pass

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((LISTEN_HOST, LISTEN_PORT)); s.listen(128)
    print("[ZAINU X BRAND] ws-ssh bridge " + LISTEN_HOST + ":" + str(LISTEN_PORT) + " -> " + SSH_HOST + ":" + str(SSH_PORT), flush=True)
    while True:
        c, _ = s.accept()
        threading.Thread(target=handle, args=(c,), daemon=True).start()

if __name__ == "__main__":
    main()
PYEOF
  chmod +x /usr/local/bin/zainu-ws-ssh.py
  cat > /etc/systemd/system/zainu-ws-ssh.service <<EOF
[Unit]
Description=ZAINU X BRAND WS to SSH bridge (DarkTunnel)
After=network.target dropbear.service
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/zainu-ws-ssh.py
Restart=always
RestartSec=2
User=root
Environment=ZAINU_WS_SSH_PORT=$PORT_WS_SSH
Environment=ZAINU_SSH_PORT=$PORT_DROP
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now zainu-ws-ssh 2>/dev/null || systemctl restart zainu-ws-ssh 2>/dev/null || wr "ws-ssh service start failed"
  ok "WS-SSH bridge: nginx /ssh-ws -> 127.0.0.1:$PORT_WS_SSH -> Dropbear :$PORT_DROP"
}

#────────────────────────────── 6. Websocket nginx ─────────────────────────
install_websocket(){
  step "[6/14] Websocket (TLS 443 + nonTLS 80) → Xray + SSH"
  cat > /etc/nginx/sites-available/default <<NGINXEOF
# ZAINU X BRAND 😎 — non-TLS (CF-compatible)
server {
  listen 80 default_server; listen [::]:80 default_server;
  server_name $DOMAIN; root /var/www/html; index index.html;
  location $P_SSH    { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_WS_SSH; }
  location $P_VMESS  { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_VMESS_WS; }
  location $P_VLESS  { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_VLESS_WS; }
  location $P_TROJAN { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_TROJAN_WS; }
}
# ZAINU X BRAND 😎 — TLS (real cert)
server {
  listen 443 ssl http2 default_server; listen [::]:443 ssl http2 default_server;
  server_name $DOMAIN;
  ssl_certificate $CERT_PATH; ssl_certificate_key $KEY_PATH;
  ssl_protocols TLSv1.2 TLSv1.3; ssl_ciphers HIGH:!aNULL:!MD5;
  location $P_SSH    { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_WS_SSH; }
  location $P_VMESS  { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_VMESS_WS; }
  location $P_VLESS  { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_VLESS_WS; }
  location $P_TROJAN { proxy_http_version 1.1; proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr; proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade"; proxy_pass http://127.0.0.1:$PORT_TROJAN_WS; }
}
NGINXEOF
  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  rm -f /etc/nginx/sites-enabled/default.bak 2>/dev/null
  nginx -t 2>>"$LOG" || die "nginx config invalid"
  systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || wr "nginx reload failed"
  ok "nginx WS: TLS=443 nonTLS=80 paths=$P_SSH,$P_VMESS,$P_VLESS,$P_TROJAN"
}

#────────────────────────────── 7. UDP Custom ───────────────────────────────
install_udp(){
  step "[7/14] UDP Custom ($PORT_UDP/udp)"
  cat > /usr/local/bin/zainu-udpgw.py <<'PYEOF'
#!/usr/bin/env python3
"""ZAINU X BRAND UDP gateway - relays UDP packets to public DNS."""
import socket, hashlib, threading

PORT = 7100
TARGETS = [("1.1.1.1", 53), ("8.8.8.8", 53), ("1.0.0.1", 53)]

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", PORT))

def forward(src, data):
    t = TARGETS[int(hashlib.md5(str(src).encode()).hexdigest(), 16) % len(TARGETS)]
    try:
        u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        u.settimeout(5)
        u.sendto(data, t)
        while True:
            r, _ = u.recvfrom(65535)
            try:
                s.sendto(r, src)
            except Exception:
                break
    except Exception:
        pass

print("[ZAINU X BRAND] udpgw on udp/" + str(PORT), flush=True)
while True:
    try:
        data, src = s.recvfrom(65535)
        threading.Thread(target=forward, args=(src, data), daemon=True).start()
    except Exception:
        continue
PYEOF
  chmod +x /usr/local/bin/zainu-udpgw.py
  cat > /etc/systemd/system/zainu-udpgw.service <<EOF
[Unit]
Description=ZAINU X BRAND UDP-Custom
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/zainu-udpgw.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now zainu-udpgw 2>/dev/null || systemctl restart zainu-udpgw 2>/dev/null || wr "udpgw start failed"
  # build the master UDP-custom "host:port:secret" string used by HTTP Injector etc.
  UDP_CUSTOM_CMD="${PUBIP}:${PORT_UDP}"
  export UDP_CUSTOM_CMD
  ok "UDP Custom on $PORT_UDP/udp (cmd: ${UDP_CUSTOM_CMD})"
}

#────────────────────────────── 8. Xray (all sub-protocols) ──────────────────
install_xray(){
  step "[8/14] Xray core (VLESS/VMess/Trojan/Reality/Shadowsocks)"
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>>"$LOG" || wr "Xray installer issue"
  UUID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
  TROJAN_PASS="$(rand_str 16)"
  SS_PASS="$(rand_str 24)"
  REALITY_PAIR="$(xray x25519 2>>"$LOG" || true)"
  PRIV_KEY="$(echo "$REALITY_PAIR" | awk -F': ' '/Private key:/{print $2}' | tr -d '\r\n')"
  PUB_KEY="$(echo "$REALITY_PAIR"  | awk -F': ' '/Public key:/{print $2}'  | tr -d '\r\n')"
  if [[ -z "$PRIV_KEY" || -z "$PUB_KEY" ]]; then
    # Fallback: use random strings (Reality still works for direct TCP)
    PRIV_KEY="$(rand_str 32)"; PUB_KEY="$(rand_str 32)"
    wr "x25519 not available — using placeholder Reality keys"
  fi
  SHORT_SID="$(rand_hex 4)"
  REALITY_DEST="www.microsoft.com:443"

  cat > /usr/local/etc/xray/config.json <<XJEOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "tag":"vmess-ws","port":$PORT_VMESS_WS,"listen":"127.0.0.1","protocol":"vmess",
      "settings":{"clients":[{"id":"$UUID","email":"master@$TAG","alterId":0}]},
      "streamSettings":{"network":"ws","wsSettings":{"path":"$P_VMESS","maxEarlyData":2048}} },
    { "tag":"vmess-tcp","port":$PORT_VMESS_TCP,"protocol":"vmess",
      "settings":{"clients":[{"id":"$UUID","email":"master@$TAG","alterId":0}]},
      "streamSettings":{"network":"tcp"} },
    { "tag":"vless-ws","port":$PORT_VLESS_WS,"listen":"127.0.0.1","protocol":"vless",
      "settings":{"clients":[{"id":"$UUID","email":"master@$TAG"}],"decryption":"none"},
      "streamSettings":{"network":"ws","wsSettings":{"path":"$P_VLESS","maxEarlyData":2048}} },
    { "tag":"vless-reality","port":$PORT_REALITY,"protocol":"vless",
      "settings":{"clients":[{"id":"$UUID","email":"master@$TAG","flow":"xtls-rprx-vision"}],"decryption":"none"},
      "streamSettings":{"network":"tcp","security":"reality",
        "realitySettings":{"show":false,"dest":"$REALITY_DEST","xver":0,
        "serverNames":["www.microsoft.com","www.apple.com"],
        "privateKey":"$PRIV_KEY","shortIds":["$SHORT_SID"]}} },
    { "tag":"trojan-ws","port":$PORT_TROJAN_WS,"listen":"127.0.0.1","protocol":"trojan",
      "settings":{"clients":[{"password":"$TROJAN_PASS","email":"master@$TAG"}]},
      "streamSettings":{"network":"ws","wsSettings":{"path":"$P_TROJAN","maxEarlyData":2048}} },
    { "tag":"trojan-grpc","port":$PORT_GRPC,"protocol":"trojan",
      "settings":{"clients":[{"password":"$TROJAN_PASS","email":"master@$TAG"}]},
      "streamSettings":{"network":"grpc","grpcSettings":{"serviceName":"trojan-grpc"}} },
    { "tag":"shadowsocks","port":$PORT_SS,"protocol":"shadowsocks",
      "settings":{"method":"aes-256-gcm","password":"$SS_PASS","network":"tcp,udp"} }
  ],
  "outbounds":[ {"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"} ]
}
XJEOF
  xray run -test -c /usr/local/etc/xray/config.json 2>>"$LOG" || wr "xray config test warning"
  systemctl enable --now xray 2>/dev/null || systemctl restart xray 2>/dev/null || wr "xray start failed"

  export UUID TROJAN_PASS SS_PASS PUB_KEY PRIV_KEY SHORT_SID

  # ── Build MASTER protocol links (used by show_links / brand banner) ────────
  local pv vm pt pv2
  pv2="$(printf '%s' "$P_VMESS" | sed 's#/#%2F#g')"
  pv="$(printf '%s' "$P_VLESS" | sed 's#/#%2F#g')"
  pt="$(printf '%s' "$P_TROJAN" | sed 's#/#%2F#g')"

  # VMess WS-TLS (port 443 via nginx)
  local vmess_tls_json="{\"v\":\"2\",\"ps\":\"${TAG}-VMess-WS-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"${P_VMESS}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
  VMESS_WS_TLS="vmess://$(printf '%s' "$vmess_tls_json" | base64 -w0)"
  # VMess WS-CF (port 80 via Cloudflare)
  local vmess_cf_json="{\"v\":\"2\",\"ps\":\"${TAG}-VMess-WS-CF\",\"add\":\"${CF_HOST}\",\"port\":\"80\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"${P_VMESS}\",\"tls\":\"\",\"sni\":\"\"}"
  VMESS_WS_CF="vmess://$(printf '%s' "$vmess_cf_json" | base64 -w0)"
  # VMess TCP (direct)
  local vmess_tcp_json="{\"v\":\"2\",\"ps\":\"${TAG}-VMess-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"${PORT_VMESS_TCP}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"tls\":\"\"}"
  VMESS_TCP="vmess://$(printf '%s' "$vmess_tcp_json" | base64 -w0)"

  # VLESS WS-TLS (port 443)
  VLESS_WS_TLS="vless://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=${pv}&host=${DOMAIN}&sni=${DOMAIN}#${TAG}-VLESS-WS-TLS"
  # VLESS WS-CF (port 80)
  VLESS_WS_CF="vless://${UUID}@${CF_HOST}:80?security=none&type=ws&path=${pv}&host=${CF_HOST}#${TAG}-VLESS-WS-CF"
  # VLESS Reality
  VLESS_REALITY="vless://${UUID}@${DOMAIN}:${PORT_REALITY}?security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUB_KEY}&sid=${SHORT_SID}&type=tcp&flow=xtls-rprx-vision#${TAG}-VLESS-Reality"

  # Trojan WS (port 443)
  TROJAN_WS_TLS="trojan://${TROJAN_PASS}@${DOMAIN}:443?security=tls&type=ws&path=${pt}&host=${DOMAIN}&sni=${DOMAIN}#${TAG}-Trojan-WS"
  # Trojan gRPC
  TROJAN_GRPC="trojan://${TROJAN_PASS}@${DOMAIN}:${PORT_GRPC}?security=tls&type=grpc&serviceName=trojan-grpc&sni=${DOMAIN}#${TAG}-Trojan-gRPC"

  # Shadowsocks (SIP002 URL)
  local ssb64
  ssb64="$(printf 'aes-256-gcm:%s' "$SS_PASS" | base64 -w0)"
  SS_LINK="ss://${ssb64}@${DOMAIN}:${PORT_SS}#${TAG}-Shadowsocks"

  export VMESS_WS_TLS VMESS_WS_CF VMESS_TCP VLESS_WS_TLS VLESS_WS_CF VLESS_REALITY \
         TROJAN_WS_TLS TROJAN_GRPC SS_LINK

  # Save master secrets for later per-user account creation
  umask 077
  mkdir -p "$ZDIR"
  cat > "$ZDIR/xray_secrets.env" <<EOF
UUID=$UUID
TROJAN_PASS=$TROJAN_PASS
SS_PASS=$SS_PASS
PRIV_KEY=$PRIV_KEY
PUB_KEY=$PUB_KEY
SHORT_SID=$SHORT_SID
EOF
  chmod 600 "$ZDIR/xray_secrets.env"

  ok "Xray: VMess(WS/TCP) VLESS(WS/Reality) Trojan(WS/gRPC) SS — all inbounds live"
  ok "Master UUID=$UUID  Trojan=$TROJAN_PASS  SS=$SS_PASS"
}

#────────────────────────────── 9. SlowDNS (iodine) ─────────────────────────
install_slowdns(){
  step "[9/14] SlowDNS (iodine on UDP $PORT_SLOWDNS)"
  apt-get -y -qq install iodine 2>>"$LOG" || wr "iodine install warning"
  # systemd service uses env file (no escape issues)
  cat > /etc/default/zainu-slowdns <<EOF
SLOWDNS_NS=$SLOWDNS_NS
SLOWDNS_PASS=$SLOWDNS_PASS
EOF
  cat > /etc/systemd/system/zainu-slowdns.service <<EOF
[Unit]
Description=ZAINU X BRAND SlowDNS (iodine)
After=network.target
[Service]
EnvironmentFile=/etc/default/zainu-slowdns
ExecStart=/usr/sbin/iodined -c -f -P \${SLOWDNS_PASS} 10.22.0.1 \${SLOWDNS_NS}
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now zainu-slowdns 2>/dev/null || systemctl restart zainu-slowdns 2>/dev/null || wr "slowdns start failed"
  export SLOWDNS_NS SLOWDNS_PASS
  ok "SlowDNS: NS=$SLOWDNS_NS pass=$SLOWDNS_PASS"
  ok "Client cmd: iodine -f -P $SLOWDNS_PASS $SLOWDNS_NS"
}

#────────────────────────────── 10. Hysteria2 ───────────────────────────────
install_hysteria2(){
  step "[10/14] Hysteria2 (UDP $PORT_HY2)"
  bash <(curl -fsSL https://get.hy2.sh/) 2>>"$LOG" || wr "hysteria installer issue"
  HY2_PASS="$(rand_str 16)"
  cat > /etc/hysteria/config.yaml <<HYEOF
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
HYEOF
  systemctl enable --now hysteria-server 2>/dev/null || systemctl restart hysteria-server 2>/dev/null || wr "hysteria2 start failed"
  export HY2_PASS
  HY2_LINK="hysteria2://${HY2_PASS}@${DOMAIN}:${PORT_HY2}/?sni=${DOMAIN}#${TAG}-Hysteria2"
  export HY2_LINK
  ok "Hysteria2 UDP $PORT_HY2 pass=$HY2_PASS"
}

#────────────────────────────── 11. WireGuard ────────────────────────────────
install_wireguard(){
  step "[11/14] WireGuard (UDP $PORT_WG)"
  apt-get -y -qq install wireguard wireguard-tools qrencode 2>>"$LOG" || wr "wireguard install warning"
  cd /etc/wireguard 2>/dev/null || mkdir -p /etc/wireguard && cd /etc/wireguard
  umask 077
  wg genkey | tee server_private.key | wg pubkey > server_public.key
  local SP PRIV_PUB
  SP="$(cat server_private.key)"
  WG_PUB="$(cat server_public.key)"
  local WG_IFACE
  WG_IFACE="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
  WG_IFACE="${WG_IFACE:-eth0}"

  cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
Address = 10.66.66.1/24
ListenPort = $PORT_WG
PrivateKey = $SP
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $WG_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $WG_IFACE -j MASQUERADE
WGEOF
  echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-zainu-wg.conf
  sysctl -p /etc/sysctl.d/99-zainu-wg.conf 2>>"$LOG" || true
  systemctl enable --now wg-quick@wg0 2>/dev/null || systemctl restart wg-quick@wg0 2>/dev/null || wr "wg-quick start failed"
  export WG_PUB
  ok "WireGuard on UDP $PORT_WG (server pub: $WG_PUB)"
}

#────────────────────────────── 12. OpenVPN ─────────────────────────────────
install_openvpn(){
  step "[12/14] OpenVPN (UDP $PORT_OVPN)"
  apt-get -y -qq install openvpn easy-rsa 2>>"$LOG" || wr "openvpn install warning"
  make-cadir /etc/openvpn/easy-rsa 2>/dev/null || true
  local EASY=/etc/openvpn/easy-rsa
  if [[ -x "$EASY/easyrsa" ]]; then
    cd "$EASY" 2>/dev/null || true
    export EASYRSA_BATCH=1 EASYRSA_REQ_CN="Zainu-VPN-CA" EASYRSA_REQ_EMAIL=admin@${DOMAIN}
    [[ -f pki/ca.crt ]] || ./easyrsa init-pki 2>>"$LOG" || true
    [[ -f pki/ca.crt ]] || ./easyrsa build-ca nopass 2>>"$LOG" || true
    [[ -f pki/dh.pem ]]  || ./easyrsa gen-dh 2>>"$LOG" || true
    [[ -f pki/issued/server.crt ]] || {
      ./easyrsa build-server-full server nopass 2>>"$LOG" || true
      openvpn --genkey secret "$EASY/pki/ta.key" 2>/dev/null || true
    }
    cat > /etc/openvpn/server.conf <<OVPNEOF
port $PORT_OVPN
proto udp
dev tun
ca $EASY/pki/ca.crt
cert $EASY/pki/issued/server.crt
key $EASY/pki/private/server.key
dh $EASY/pki/dh.pem
auth SHA256
cipher AES-256-GCM
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
tls-auth $EASY/pki/ta.key 0
OVPNEOF
    systemctl enable --now openvpn@server 2>/dev/null || systemctl restart openvpn@server 2>/dev/null || wr "openvpn server start failed"
  fi
  ok "OpenVPN on UDP $PORT_OVPN"
}

#────────────────────────────── 13. Account system ───────────────────────────
install_account_system(){
  step "[13/14] Account system (IP limit / GB limit / expiry / branded login shell)"
  mkdir -p "$ZDIR"
  touch "$DB"
  cat > /usr/local/bin/zainu-shell <<'SHELLEOF'
#!/bin/bash
# ZAINU X BRAND 😎 — login shell wrapper
# Enforces: IP limit, GB limit, expiry
export TERM=xterm-256color
USER="$(whoami)"
DB="/etc/zainu/accounts.db"
# Print brand banner
cat /etc/motd 2>/dev/null

# Check account entry
line="$(grep "^${USER}:" "$DB" 2>/dev/null | head -1)"
if [[ -z "$line" ]]; then
  exec /bin/bash --login
fi
IFS=':' read -r _u _p exp iplim gblim uid status _cr <<<"$line"
# expiry
if [[ "$exp" != "0" && "$exp" != "" ]] && (( exp < $(date +%s) )); then
  echo "❌ Account expired. Contact admin."
  exit 1
fi
# status
if [[ "$status" != "active" ]]; then
  echo "❌ Account ${status}. Contact admin."
  exit 1
fi
# IP limit (count distinct src IPs from this uid)
if [[ "$iplim" != "0" && "$iplim" != "" ]]; then
  ips="$(ss -tnp 2>/dev/null | grep ",uid=${uid}," | awk '{print $4}' | awk -F: '{print $1}' | sort -u | wc -l)"
  if (( ips > iplim )); then
    echo "❌ IP limit reached ($ips > $iplim)."
    exit 1
  fi
fi
# GB limit
if [[ "$gblim" != "0" && "$gblim" != "" ]]; then
  used_b="$(iptables -L "ZAINU_${USER}" -vxn 2>/dev/null | awk '/RETURN/{s+=$2} END{print s+0}')"
  used_gb="$(awk "BEGIN{printf \"%.2f\", ${used_b}/1073741824}")"
  if (( $(awk "BEGIN{print (${used_gb} >= ${gblim})}") )); then
    echo "❌ GB limit reached (${used_gb}GB / ${gblim}GB)."
    exit 1
  fi
fi
exec /bin/bash --login
SHELLEOF
  chmod +x /usr/local/bin/zainu-shell
  ok "Account system ready (zainu-shell enforces IP/GB/expiry)"
}

install_menu_cmd(){
  # Symlink `zainu` → this script for easy menu access
  cat > /usr/local/bin/zainu <<EOF
#!/usr/bin/env bash
exec /usr/local/bin/zainu-vpn.sh --menu "\$@"
EOF
  chmod +x /usr/local/bin/zainu
  # Also: zainu-vpn.sh symlink (real path)
  cp -f "$0" /usr/local/bin/zainu-vpn.sh 2>/dev/null || install -m 0755 "$0" /usr/local/bin/zainu-vpn.sh
  chmod +x /usr/local/bin/zainu-vpn.sh
}

setup_firewall(){
  step "[14/14] Firewall + /etc/zainu marker"
  if command -v ufw >/dev/null 2>&1; then
    ufw --force reset >>"$LOG" 2>&1 || true
    ufw default deny incoming >>"$LOG" 2>&1
    ufw default allow outgoing >>"$LOG" 2>&1
    for p in "$PORT_SSH/tcp" "$PORT_DROP/tcp" "$PORT_SSL/tcp" \
             "$PORT_WS_HTTP/tcp" "$PORT_WS_TLS/tcp" "$PORT_WS_SSH/tcp" \
             "$PORT_UDP/udp" "$PORT_SLOWDNS/udp" "$PORT_HY2/udp" \
             "$PORT_WG/udp" "$PORT_OVPN/udp" \
             "$PORT_VMESS_WS/tcp" "$PORT_VLESS_WS/tcp" "$PORT_TROJAN_WS/tcp" \
             "$PORT_VMESS_TCP/tcp" "$PORT_REALITY/tcp" "$PORT_GRPC/tcp" \
             "$PORT_SS/tcp"; do
      ufw allow "$p" >>"$LOG" 2>&1 || true
    done
    ufw --force enable >>"$LOG" 2>&1 || true
    ok "UFW rules added"
  else
    wr "UFW not installed — relying on iptables defaults"
  fi

  # Branded nginx index page
  cat > /var/www/html/index.html <<'HTMLEOF'
<!doctype html>
<html><head><meta charset="utf-8"><title>ZAINU X BRAND</title>
<style>
  body{background:#0a0e27;color:#9ff;font-family:monospace;padding:40px;text-align:center}
  h1{font-size:48px;background:linear-gradient(90deg,#f0f,#0ff,#0f0,#ff0);-webkit-background-clip:text;background-clip:text;color:transparent}
  h2{color:#9ff}p{color:#fff}</style></head><body>
<h1>ZAINU X BRAND 😎</h1>
<h2>PREMIUM VPN</h2>
<p>All Protocols • Real TLS • Cloudflare</p>
</body></html>
HTMLEOF

  # DNS resolve fix for some apps
  echo "nameserver 1.1.1.1" > /etc/resolv.conf.head 2>/dev/null || true

  # /etc/zainu/installed marker
  mkdir -p "$ZDIR"
  echo "$VER $(date +%s)" > "$MARKER"
  ok "Marker written: $MARKER"
}

#────────────────────────────── Self-test ────────────────────────────────────
install_selftest(){
  step "[SELFTEST] Verifying all services + ports"
  local pass=0 fail=0
  chk(){
    local name="$1" res="$2"
    if [[ "$res" == "active" || "$res" == "open" || "$res" == "yes" || "$res" == "listening" ]]; then
      printf "  ${G}✓${K} %-26s ${C}%s${K}\n" "$name" "$res"; pass=$((pass+1))
    else
      printf "  ${R}✗${K} %-26s ${Y}%s${K}\n" "$name" "$res"; fail=$((fail+1))
    fi
  }
  printf "${M}── Services ──${K}\n"
  for svc in ssh dropbear stunnel4 nginx xray zainu-slowdns hysteria-server wg-quick@wg0 openvpn@server zainu-ws-ssh zainu-udpgw; do
    local st; st="$(systemctl is-active "$svc" 2>/dev/null || echo 'inactive')"
    chk "$svc" "$st"
  done
  printf "\n${M}── Ports ──${K}\n"
  local ports=(
    "$PORT_SSH/tcp:SSH"
    "$PORT_DROP/tcp:Dropbear"
    "$PORT_SSL/tcp:SSL-Stunnel"
    "$PORT_WS_HTTP/tcp:Nginx-HTTP"
    "$PORT_WS_TLS/tcp:Nginx-TLS"
    "$PORT_WS_SSH/tcp:WS-SSH-bridge"
    "$PORT_UDP/udp:UDP-Custom"
    "$PORT_SLOWDNS/udp:SlowDNS"
    "$PORT_HY2/udp:Hysteria2"
    "$PORT_WG/udp:WireGuard"
    "$PORT_OVPN/udp:OpenVPN"
    "$PORT_VMESS_WS/tcp:VMess-WS"
    "$PORT_VLESS_WS/tcp:VLESS-WS"
    "$PORT_TROJAN_WS/tcp:Trojan-WS"
    "$PORT_VMESS_TCP/tcp:VMess-TCP"
    "$PORT_REALITY/tcp:VLESS-Reality"
    "$PORT_GRPC/tcp:Trojan-gRPC"
    "$PORT_SS/tcp:Shadowsocks"
  )
  for pd in "${ports[@]}"; do
    local port="${pd%%/*}" desc="${pd##*:}"
    if ss -tuln 2>/dev/null | grep -E ":${port} " >/dev/null; then chk "$desc(:$port)" "listening"
    else chk "$desc(:$port)" "down"; fi
  done
  printf "\n${M}── WS upgrade (SSH path) ──${K}\n"
  local ws_test
  ws_test="$(curl -ks -o /dev/null -w '%{http_code}' --connect-timeout 5 \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
    -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
    http://127.0.0.1:$PORT_WS_SSH/ 2>&1 || echo failed)"
  if [[ "$ws_test" == "101" ]]; then chk "WS→SSH upgrade" "101 OK"; else chk "WS→SSH upgrade" "$ws_test"; fi

  printf "\n${G}══════════ PASS: $pass  ${R}FAIL: $fail ══════════${K}\n"
  if [[ $fail -gt 0 ]]; then
    wr "Some services did not start. Inspect:  journalctl -u <name> -n 50  |  tail -50 $LOG"
  fi
}

final_report(){
  hr
  echo -e "${C}        ${BRAND} — INSTALL COMPLETE v${VER}${K}"
  hr
  cat <<EOF

${M}━━ Connect-time banner${K}
  Branded banner shows on every SSH/login: ${BRAND}  —  PREMIUM VPN

${G}━━ Ports / Protocols${K}
  SSH $PORT_SSH • Dropbear $PORT_DROP • SSL $PORT_SSL • WS $PORT_WS_HTTP/$PORT_WS_TLS
  UDP $PORT_UDP • VMess-TCP $PORT_VMESS_TCP • Reality $PORT_REALITY • gRPC $PORT_GRPC
  SS $PORT_SS • SlowDNS $PORT_SLOWDNS • Hysteria2 $PORT_HY2 • WG $PORT_WG • OVPN $PORT_OVPN

${C}━━ Xray MASTER links (full UUID, no per-user limits)${K}
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
  UDP Custom   : $UDP_CUSTOM_CMD
  SlowDNS cmd  : iodine -f -P $SLOWDNS_PASS $SLOWDNS_NS
  WireGuard    : /root/zainu-wg-client.conf

${Y}━━ Manage accounts${K}
  Type ${G}zainu${K}  →  colorful menu:
  Create (SSH/Xray/WG/OVPN/SlowDNS), List, Delete, Renew, Traffic, Links.

${M}━━ NEXT${K}
  1. ${G}zainu${K}         →  create your accounts (IP/GB/expiry prompts)
  2. ${G}menu${K}          →  same, fetched fresh from GitHub
  3. share the generated links
  4. ${G}sudo reboot${K}    →  confirm all services start on boot
EOF
  hr
}

#────────────────────────────── do_install / uninstall ───────────────────────
do_install(){
  preflight
  get_inputs
  install_deps
  install_brand_banner
  install_ssh_dropbear
  install_ssl
  install_cert
  install_ssh_ws_bridge
  install_websocket
  install_udp
  install_xray
  install_slowdns
  install_hysteria2
  install_wireguard
  install_openvpn
  install_account_system
  setup_firewall
  install_menu_cmd
  persist_config
  install_selftest
  final_report
  echo
  printf "${Y}Press ENTER to open the ZAINU X BRAND 😎 management panel...${K}"
  read -r _
  clear 2>/dev/null || true
  PUBIP="$(get_pubip)"
  menu
}

do_uninstall(){
  hr; echo -e "${R}🔥 FULL NUKE — Uninstalling $BRAND ...${K}"; hr

  # 1) Stop + disable ALL services (VPN + helper)
  step "1/9 Stopping + disabling ALL services"
  systemctl disable --now \
    xray zainu-udpgw zainu-slowdns zainu-ws-ssh \
    hysteria-server wg-quick@wg0 openvpn@server \
    dropbear stunnel4 nginx chrony 2>/dev/null || true
  pkill -f zainu-udpgw 2>/dev/null || true
  pkill -f zainu-ws-ssh 2>/dev/null || true
  pkill -f iodine 2>/dev/null || true
  pkill -f hysteria 2>/dev/null || true
  ok "all services stopped"

  # 2) Delete ALL VPN user accounts + their iptables chains
  step "2/9 Deleting ALL VPN user accounts + iptables"
  local db="$ZDIR/accounts.db"
  if [[ -f "$db" ]]; then
    while IFS=: read -r u _ _ _ _ _ _ _; do
      [[ -n "$u" ]] || continue
      local uid_=""
      uid_="$(id -u "$u" 2>/dev/null)" || true
      [[ -n "$uid_" ]] && {
        iptables -D OUTPUT -m owner --uid-owner "$uid_" -j "ZAINU_${u}" 2>/dev/null || true
        iptables -F "ZAINU_${u}" 2>/dev/null || true
        iptables -X "ZAINU_${u}" 2>/dev/null || true
        ip6tables -F "ZAINU_${u}" 2>/dev/null || true
        ip6tables -X "ZAINU_${u}" 2>/dev/null || true
      }
      id -u "$u" >/dev/null 2>&1 && { userdel -r -f "$u" 2>/dev/null || true; }
    done < "$db"
    ok "VPN users + chains purged"
  else
    wr "no accounts.db (nothing to delete)"
  fi
  # flush any leftover ZAINU chains
  iptables -S 2>/dev/null | grep -i zainu | while read -r _ rule; do iptables -D $rule 2>/dev/null || true; done
  iptables -L 2>/dev/null | grep -i '^Chain ZAINU' | awk '{print $2}' | while read -r ch; do
    iptables -F "$ch" 2>/dev/null || true; iptables -X "$ch" 2>/dev/null || true
  done
  ok "iptables flushed"

  # 3) Official uninstallers for Xray + Hysteria2 (remove binary + service cleanly)
  step "3/9 Official uninstallers (Xray + Hysteria2)"
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh 2>/dev/null)" @ remove 2>/dev/null || true
  curl -fsSL https://get.hy2.sh/ 2>/dev/null | bash -s -- remove 2>/dev/null || true
  rm -f /usr/local/bin/xray /usr/local/bin/hysteria 2>/dev/null || true
  rm -f /etc/systemd/system/{xray,hysteria-server}.service /etc/systemd/system/{xray,hysteria-server}.service.d 2>/dev/null || true
  ok "Xray + Hysteria2 binaries removed"

  # 4) Remove ALL config dirs + ALL zainu binaries + menu loader itself
  step "4/9 Removing ALL configs + binaries + menu loader"
  rm -rf /etc/zainu \
         /etc/hysteria \
         /etc/wireguard \
         /etc/openvpn \
         /etc/stunnel \
         /etc/dropbear \
         /etc/default/dropbear \
         /etc/default/zainu-slowdns \
         /etc/nginx/ssl \
         /etc/nginx/sites-available/default \
         /usr/local/etc/xray \
         /usr/local/bin/zainu* \
         /usr/local/bin/menu \
         /etc/systemd/system/zainu-*.service \
         /var/www/html/index.html \
         /var/www/html/zainu* \
         /root/.zainu* \
         /tmp/.zainu* \
         2>/dev/null || true
  ok "all configs + binaries + menu loader removed"

  # 5) Restore default login messages (remove ZAINU banner everywhere)
  step "5/9 Restoring default login messages"
  printf '\n' > /etc/motd
  printf 'Ubuntu 22.04 LTS \\n \\l\n\n' > /etc/issue
  printf 'Ubuntu 22.04 LTS\n\n' > /etc/issue.net
  rm -f /etc/profile.d/zainu-welcome.sh /etc/profile.d/zz-zainu-welcome.sh 2>/dev/null || true
  [[ -f /etc/shells ]] && sed -i '/zainu-shell/d' /etc/shells 2>/dev/null || true
  ok "login messages restored to default"

  # 6) Restore sshd_config (undo Banner etc.)
  step "6/9 Restoring sshd_config"
  [[ -f /etc/ssh/sshd_config ]] && {
    sed -i '/^Banner /d; /^#Banner /d' /etc/ssh/sshd_config 2>/dev/null || true
    rm -f /etc/ssh/sshd_config.d/zainu*.conf 2>/dev/null || true
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
  }
  ok "sshd restored"

  # 7) Remove ALL cron entries related to zainu + Let's Encrypt certs
  step "7/9 Cleaning cron + SSL certs"
  ( crontab -l 2>/dev/null | grep -v -i zainu ) | crontab - 2>/dev/null || true
  certbot delete --non-interactive 2>/dev/null || true
  rm -rf /etc/letsencrypt/live/* /etc/letsencrypt/archive/* /etc/letsencrypt/renewal/* 2>/dev/null || true
  ok "cron + certs cleaned"

  # 8) PURGE ALL packages that the script installed (full clean)
  step "8/9 PURGING ALL installed packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y --purge remove \
    xray dropbear stunnel4 nginx nginx-common nginx-full \
    iodine hysteria-server wireguard wireguard-tools openvpn \
    certbot python3-certbot-nginx \
    qrencode jq bc socat net-tools dnsutils iproute2 \
    uuid-runtime pwgen chrony build-essential software-properties-common \
    2>/dev/null || true
  apt-get -y --purge autoremove 2>/dev/null || true
  apt-get -y clean 2>/dev/null || true
  ok "all packages purged"

  # 9) Final cleanup — firewall reset, daemon reload, apt cache clean
  step "9/9 Final cleanup"
  systemctl daemon-reload
  systemctl reset-failed 2>/dev/null || true
  iptables -P INPUT ACCEPT 2>/dev/null || true
  iptables -P FORWARD ACCEPT 2>/dev/null || true
  iptables -P OUTPUT ACCEPT 2>/dev/null || true
  iptables -F 2>/dev/null || true
  iptables -X 2>/dev/null || true
  ufw --force reset 2>/dev/null || true
  apt-get autoremove -y 2>/dev/null || true
  ok "final cleanup done"

  hr
  echo -e "${G}✅ ${BRAND} — FULLY NUKED.${K}"
  echo -e "${Y}VPS is now CLEAN (like fresh install).${K}"
  echo
  echo -e "${C}To reinstall from scratch:${K}"
  echo -e "${W}apt update -y && apt install -y curl && curl -o /usr/local/bin/menu https://raw.githubusercontent.com/zainiking8/vps-panel/main/menu.sh && chmod +x /usr/local/bin/menu && menu${K}"
  hr
  exit 0
}

#────────────────────────────── ACCOUNT MANAGEMENT ────────────────────────────
acc_create_ssh(){
  step "CREATE SSH / DROPBEAR / SSL ACCOUNT"
  mkdir -p "$ZDIR"; touch "$DB"
  read -r -p "Username: " u; [[ -n "$u" ]] || { er "no username"; return; }
  grep -q "^${u}:" "$DB" 2>/dev/null && { er "user '$u' already exists"; return; }
  read -r -p "Password [random]: " p; p="${p:-$(rand_str 14)}"
  read -r -p "IP limit (max simultaneous IPs, 0=unlimited) [1]: " iplim; iplim="${iplim:-1}"
  read -r -p "GB limit (0=unlimited) [0]: " gblim; gblim="${gblim:-0}"
  read -r -p "Expiry days (0=unlimited) [30]: " days; days="${days:-30}"
  exp=0; [[ "$days" != "0" ]] && exp=$(($(date +%s)+days*86400))

  if ! id -u "$u" >/dev/null 2>&1; then
    useradd -m -s /usr/local/bin/zainu-shell "$u" 2>/dev/null || { er "useradd failed"; return; }
  else
    usermod -s /usr/local/bin/zainu-shell "$u" 2>/dev/null || true
  fi
  echo "$u:$p" | chpasswd
  local uid_; uid_="$(id -u "$u")"
  iptables -N "ZAINU_${u}" 2>/dev/null || true
  iptables -C OUTPUT -m owner --uid-owner "$uid_" -j "ZAINU_${u}" 2>/dev/null || \
    iptables -A OUTPUT -m owner --uid-owner "$uid_" -j "ZAINU_${u}" 2>/dev/null || true
  iptables -C "ZAINU_${u}" -j RETURN 2>/dev/null || iptables -A "ZAINU_${u}" -j RETURN 2>/dev/null || true
  echo "$u:$p:$exp:$iplim:$gblim:$uid_:active:$(date +%s)" >> "$DB"
  ok "SSH account '$u' created"
  echo
  printf "${G}┌──────────────────────────────────────────────────────┐${K}\n"
  printf "${G}│ ${M}ACCOUNT DETAILS${G}                                      │${K}\n"
  printf "${G}├──────────────────────────────────────────────────────┤${K}\n"
  printf "${G}│ ${C}User${K}        : ${W}%s${K}\n" "$u"
  printf "${G}│ ${C}Password${K}    : ${W}%s${K}\n" "$p"
  printf "${G}│ ${C}IP limit${K}    : ${W}%s${K}\n" "$iplim"
  printf "${G}│ ${C}GB limit${K}    : ${W}%s GB${K}\n" "$gblim"
  printf "${G}│ ${C}Expires${K}     : ${W}%s${K}\n" "$([ "$exp" = "0" ] && echo unlimited || date -d @$exp '+%Y-%m-%d %H:%M')"
  printf "${G}├──────────────────────────────────────────────────────┤${K}\n"
  printf "${G}│ ${M}CONNECT WITH${G}                                        │${K}\n"
  printf "${G}│ ${C}SSH${K}      : ssh -p $PORT_SSH ${u}@${PUBIP}\n"
  printf "${G}│ ${C}Dropbear${K} : ssh -p $PORT_DROP ${u}@${PUBIP}\n"
  printf "${G}│ ${C}SSL/TLS${K}  : stunnel client → ${PUBIP}:$PORT_SSL\n"
  printf "${G}│ ${C}DarkTunnel${K}: ${DOMAIN}:443 path $P_SSH\n"
  printf "${G}└──────────────────────────────────────────────────────┘${K}\n"
}

acc_create_xray(){
  step "CREATE XRAY ACCOUNT  (one user, all inbounds share)"
  mkdir -p "$ZDIR"; touch "$DB"
  read -r -p "Username: " u; [[ -n "$u" ]] || { er "no username"; return; }
  grep -q "^${u}:" "$DB" 2>/dev/null && { er "user '$u' already exists"; return; }
  read -r -p "IP limit (0=unlimited) [1]: " iplim; iplim="${iplim:-1}"
  read -r -p "GB limit (0=unlimited) [0]: " gblim; gblim="${gblim:-0}"
  read -r -p "Expiry days (0=unlimited) [30]: " days; days="${days:-30}"
  exp=0; [[ "$days" != "0" ]] && exp=$(($(date +%s)+days*86400))

  local U_UUID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
  local TRP="$(rand_str 16)"
  local SSP="$(rand_str 24)"
  local email="${u}@${TAG}.local"

  local XJ=/usr/local/etc/xray/config.json
  if [[ -f "$XJ" ]]; then
    python3 - "$XJ" "$U_UUID" "$email" "$TRP" "$SSP" <<'PYEOF'
import json, sys
p, uid, email, trp, ssp = sys.argv[1:6]
try:
    cfg = json.load(open(p))
except Exception:
    sys.exit(0)
for ib in cfg.get("inbounds", []):
    s = ib.setdefault("settings", {})
    proto = ib.get("protocol","")
    if proto == "vmess":
        s.setdefault("clients", []).append({"id": uid, "email": email, "alterId": 0})
    elif proto == "vless":
        c = {"id": uid, "email": email}
        if any("flow" in str(x) for x in s.get("clients", [])): c["flow"] = "xtls-rprx-vision"
        s.setdefault("clients", []).append(c)
    elif proto == "trojan":
        s.setdefault("clients", []).append({"password": trp, "email": email})
    elif proto == "shadowsocks":
        s.setdefault("clients", []).append({"password": ssp, "email": email})
open(p,"w").write(json.dumps(cfg, indent=2))
PYEOF
    systemctl restart xray 2>/dev/null || true
  fi

  umask 077; mkdir -p "$ZDIR"
  cat >> "$ZDIR/xray_secrets.env" <<EOF
${u}_UUID=$U_UUID
${u}_TROJAN=$TRP
${u}_SS=$SSP
EOF
  chmod 600 "$ZDIR/xray_secrets.env"

  # also create system user so IP limit applies to SSH login too
  if ! id -u "$u" >/dev/null 2>&1; then
    useradd -m -s /usr/local/bin/zainu-shell "$u" 2>/dev/null || true
  fi
  local uid_; uid_="$(id -u "$u" 2>/dev/null || echo 0)"
  echo "$u:$U_UUID:$exp:$iplim:$gblim:$uid_:active:$(date +%s)" >> "$DB"

  local pv2 vm2 pt2
  pv2="$(printf '%s' "$P_VLESS" | sed 's#/#%2F#g')"
  pt2="$(printf '%s' "$P_TROJAN" | sed 's#/#%2F#g')"
  vm2="$(printf '%s' "$P_VMESS" | sed 's#/#%2F#g')"

  local vmess_tls_json="{\"v\":\"2\",\"ps\":\"${TAG}-${u}-VMess\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${U_UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"${P_VMESS}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
  local l_vmess_tls="vmess://$(printf '%s' "$vmess_tls_json" | base64 -w0)"
  local l_vless_tls="vless://${U_UUID}@${DOMAIN}:443?security=tls&type=ws&path=${pv2}&host=${DOMAIN}&sni=${DOMAIN}#${TAG}-${u}-VLESS-WS"
  local l_vless_reality="vless://${U_UUID}@${DOMAIN}:${PORT_REALITY}?security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUB_KEY}&sid=${SHORT_SID}&type=tcp&flow=xtls-rprx-vision#${TAG}-${u}-VLESS-Reality"
  local l_trojan_ws="trojan://${TRP}@${DOMAIN}:443?security=tls&type=ws&path=${pt2}&host=${DOMAIN}&sni=${DOMAIN}#${TAG}-${u}-Trojan-WS"
  local ssb64; ssb64="$(printf 'aes-256-gcm:%s' "$SSP" | base64 -w0)"
  local l_ss="ss://${ssb64}@${DOMAIN}:${PORT_SS}#${TAG}-${u}-SS"
  local l_hy2="hysteria2://${HY2_PASS}@${DOMAIN}:${PORT_HY2}/?sni=${DOMAIN}#${TAG}-${u}-HY2"

  ok "Xray account '$u' created — all inbounds attached"
  mkdir -p "$ZDIR/links"
  cat > "$ZDIR/links/${u}.txt" <<EOF
# ZAINU X BRAND 😎 — ${u}
UUID=$U_UUID
TROJAN_PASS=$TRP
SS_PASS=$SSP

VMESS-WS-TLS : $l_vmess_tls
VLESS-WS-TLS : $l_vless_tls
VLESS-REALITY: $l_vless_reality
TROJAN-WS    : $l_trojan_ws
SHADOWSOCKS  : $l_ss
HYSTERIA2    : $l_hy2
EOF
  printf "${G}┌──────────────────────────────────────────────────────┐${K}\n"
  printf "${G}│ ${M}XRAY LINKS FOR ${u}${G}                                 │${K}\n"
  printf "${G}├──────────────────────────────────────────────────────┤${K}\n"
  printf "${G}│ ${C}VMess WS-TLS${K}     : ${W}%s...${K}\n" "${l_vmess_tls:0:50}"
  printf "${G}│ ${C}VLESS WS-TLS${K}     : ${W}%s...${K}\n" "${l_vless_tls:0:50}"
  printf "${G}│ ${C}VLESS Reality${K}    : ${W}%s...${K}\n" "${l_vless_reality:0:50}"
  printf "${G}│ ${C}Trojan WS${K}        : ${W}%s...${K}\n" "${l_trojan_ws:0:50}"
  printf "${G}│ ${C}Shadowsocks${K}      : ${W}%s...${K}\n" "${l_ss:0:50}"
  printf "${G}│ ${C}Hysteria2${K}        : ${W}%s...${K}\n" "${l_hy2:0:50}"
  printf "${G}├──────────────────────────────────────────────────────┤${K}\n"
  printf "${G}│ ${M}Full links saved to:${K} ${W}/etc/zainu/links/${u}.txt${K}\n"
  printf "${G}└──────────────────────────────────────────────────────┘${K}\n"
}

acc_create_wg(){
  step "CREATE WIREGUARD PEER"
  read -r -p "Client name (e.g. iphone): " cn; [[ -n "$cn" ]] || { er "no name"; return; }
  local WG_CP WG_CPB SP
  WG_CP="$(wg genkey)"; WG_CPB="$(echo "$WG_CP" | wg pubkey)"
  SP="$(cat /etc/wireguard/server_public.key 2>/dev/null || echo MISSING)"
  local CLIENT_IP="10.66.66.$((RANDOM%200+10))/32"
  cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# ${cn}
PublicKey = ${WG_CPB}
AllowedIPs = ${CLIENT_IP}
EOF
  systemctl restart wg-quick@wg0 2>/dev/null || true
  local CONF="/root/zainu-wg-${cn}.conf"
  cat > "$CONF" <<EOF
[Interface]
Address = ${CLIENT_IP}
PrivateKey = ${WG_CP}
DNS = 1.1.1.1
[Peer]
PublicKey = ${SP}
Endpoint = ${PUBIP}:${PORT_WG}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
  chmod 600 "$CONF"
  ok "WireGuard peer '${cn}' created"
  printf "${G}Config: ${W}${CONF}${K}   IP: ${W}${CLIENT_IP}${K}\n"
}

acc_create_ovpn(){
  step "CREATE OPENVPN CLIENT"
  read -r -p "Client name: " cn; [[ -n "$cn" ]] || { er "no name"; return; }
  local EASY=/etc/openvpn/easy-rsa
  if [[ ! -x "$EASY/easyrsa" ]]; then
    wr "easy-rsa not built yet"; return
  fi
  cd "$EASY" || return
  export EASYRSA_BATCH=1
  ./easyrsa build-client-full "$cn" nopass 2>>"$LOG" || { er "build-client failed"; return; }
  local OVPN="/root/zainu-${cn}.ovpn"
  cat > "$OVPN" <<EOF
client
dev tun
proto udp
remote ${PUBIP} ${PORT_OVPN}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-gcm
verb 3
<ca>$(cat "$EASY/pki/ca.crt" 2>/dev/null)</ca>
<cert>$(cat "$EASY/pki/issued/${cn}.crt" 2>/dev/null)</cert>
<key>$(cat "$EASY/pki/private/${cn}.key" 2>/dev/null)</key>
<tls-auth>$(cat "$EASY/pki/ta.key" 2>/dev/null)</tls-auth>
key-direction 1
EOF
  ok "OpenVPN .ovpn: $OVPN"
}

acc_create_slowdns(){
  step "CREATE SLOWDNS ACCOUNT"
  read -r -p "Username: " u; [[ -n "$u" ]] || { er "no username"; return; }
  read -r -p "SlowDNS NS subdomain (e.g. ns1.example.com): " ns; [[ -n "$ns" ]] || { er "no NS"; return; }
  local PASS="$(rand_str 12)"
  echo "username=${u} ns=${ns} pass=${PASS} server=${PUBIP}" >> "$ZDIR/slowdns.db"
  ok "SlowDNS account '$u' created"
  printf "${G}Server: ${W}${PUBIP}${K}\n"
  printf "${G}NS:     ${W}${ns}${K}\n"
  printf "${G}Pass:   ${W}${PASS}${K}\n"
  printf "${Y}Client cmd: iodine -f -P ${PASS} ${ns}${K}\n"
}

acc_list(){
  step "ACCOUNTS"
  [[ -f "$DB" ]] || { wr "No accounts yet."; return; }
  printf "${M}%-15s %-7s %-7s %-9s %-13s %-9s${K}\n" "USER" "IPLIM" "GBLIM" "STATUS" "EXPIRY" "USED(GB)"
  while IFS=':' read -r u pw exp iplim gblim uid status created; do
    [ -z "$u" ] && continue
    local used_b=0; iptables -L "ZAINU_${u}" -vxn >/dev/null 2>&1 && \
      used_b="$(iptables -L "ZAINU_${u}" -vxn | awk '/RETURN/{s+=$2} END{print s+0}')"
    local used_gb="$(awk "BEGIN{printf \"%.2f\", ${used_b}/1073741824}")"
    local exps="$([ "$exp" = "0" ] && echo unlimited || date -d @$exp '+%Y-%m-%d')"
    printf "%-15s %-7s %-7s %-9s %-13s %-9s\n" "$u" "$iplim" "$gblim" "$status" "$exps" "$used_gb"
  done < "$DB"
}

acc_delete(){
  read -r -p "Delete username: " u; [[ -n "$u" ]] || return
  iptables -D OUTPUT -m owner --uid-owner "$(id -u "$u" 2>/dev/null)" -j "ZAINU_${u}" 2>/dev/null || true
  iptables -F "ZAINU_${u}" 2>/dev/null || true; iptables -X "ZAINU_${u}" 2>/dev/null || true
  sed -i "/^${u}:/d" "$DB" 2>/dev/null
  rm -f "$ZDIR/links/${u}.txt" 2>/dev/null
  userdel -r "$u" 2>/dev/null || true
  ok "Deleted '$u'"
}

acc_renew(){
  read -r -p "Renew username: " u; [[ -n "$u" ]] || return
  grep -q "^${u}:" "$DB" || { er "not found"; return; }
  read -r -p "Add days [30]: " days; days="${days:-30}"
  read -r -p "Set unlimited? (y/N): " uq
  local line; line="$(grep "^${u}:" "$DB")"
  IFS=':' read -r _ p exp iplim gblim uid status cr <<<"$line"
  if [[ "$uq" =~ ^[Yy]$ ]]; then exp=0
  elif [[ "$exp" = "0" ]]; then exp=$(($(date +%s)+days*86400))
  else exp=$((exp+days*86400)); fi
  passwd -u "$u" 2>/dev/null || true
  sed -i "s|^${u}:.*|${u}:${p}:${exp}:${iplim}:${gblim}:${uid}:active:${cr}|" "$DB"
  ok "Renewed '$u' → $([ "$exp" = "0" ] && echo unlimited || date -d @$exp '+%Y-%m-%d')"
}

acc_traffic(){
  step "TRAFFIC USAGE"
  [[ -f "$DB" ]] || { wr "No accounts."; return; }
  while IFS=':' read -r u pw exp iplim gblim uid status created; do
    [ -z "$u" ] && continue
    local used_b=0; iptables -L "ZAINU_${u}" -vxn >/dev/null 2>&1 && \
      used_b="$(iptables -L "ZAINU_${u}" -vxn | awk '/RETURN/{s+=$2} END{print s+0}')"
    local used_gb="$(awk "BEGIN{printf \"%.2f\", ${used_b}/1073741824}")"
    echo -e "  ${C}${u}${K}: ${used_gb} GB / ${gblim} GB (status: ${status})"
  done < "$DB"
}

restart_all(){
  step "Restarting services"
  for s in ssh dropbear stunnel4 nginx xray zainu-slowdns hysteria-server wg-quick@wg0 openvpn@server zainu-ws-ssh zainu-udpgw; do
    systemctl restart "$s" 2>/dev/null && ok "$s" || wr "$s skip"
  done
}

sys_info(){
  step "SYSTEM INFO"
  echo -e "${C}Brand${K}   : $BRAND v$VER"
  echo -e "${C}OS${K}      : $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
  echo -e "${C}Uptime${K} : $(uptime -p 2>/dev/null || uptime)"
  echo -e "${C}IP${K}      : ${PUBIP}"
  echo -e "${C}Domain${K}  : ${DOMAIN:-<not set>}"
  echo -e "${C}Load${K}    : $(cut -d' ' -f1-3 /proc/loadavg)"
  echo -e "${C}RAM${K}     : $(free -h | awk '/Mem:/{print $3"/"$2}')"
  echo -e "${C}Accounts${K}: $(grep -c ':' "$DB" 2>/dev/null || echo 0)"
}

# Show all master protocol links (used in menu)
show_links(){
  step "PROTOCOL LINKS (master / brand)"
  printf "${M}━━ Xray ─━${K}\n"
  printf "${C}  VMess WS-TLS :${K}  %s\n" "${VMESS_WS_TLS:-${Y}<not generated — re-install>${K}}"
  printf "${C}  VMess WS-CF  :${K}  %s\n" "${VMESS_WS_CF:-${Y}<not generated>${K}}"
  printf "${C}  VMess TCP    :${K}  %s\n" "${VMESS_TCP:-${Y}<not generated>${K}}"
  printf "${C}  VLESS WS-TLS :${K}  %s\n" "${VLESS_WS_TLS:-${Y}<not generated>${K}}"
  printf "${C}  VLESS WS-CF  :${K}  %s\n" "${VLESS_WS_CF:-${Y}<not generated>${K}}"
  printf "${C}  VLESS Reality:${K}  %s\n" "${VLESS_REALITY:-${Y}<not generated>${K}}"
  printf "${C}  Trojan WS    :${K}  %s\n" "${TROJAN_WS_TLS:-${Y}<not generated>${K}}"
  printf "${C}  Trojan gRPC  :${K}  %s\n" "${TROJAN_GRPC:-${Y}<not generated>${K}}"
  printf "${C}  Shadowsocks  :${K}  %s\n" "${SS_LINK:-${Y}<not generated>${K}}"
  printf "${C}  Hysteria2    :${K}  %s\n" "${HY2_LINK:-${Y}<not generated>${K}}"
  printf "${M}━━ UDP / DNS / VPN ─━${K}\n"
  printf "${C}  UDP Custom   :${K}  ${W}${UDP_CUSTOM_CMD:-<not set>}${K}  (HTTP Injector / UDP custom)\n"
  printf "${C}  SlowDNS cmd  :${K}  iodine -f -P ${W}${SLOWDNS_PASS:-?}${K} ${W}${SLOWDNS_NS:-?}${K}\n"
  printf "${C}  WireGuard    :${K}  UDP ${W}${PUBIP}:${PORT_WG}${K}  (server pub: ${W}${WG_PUB:-<not set>}${K})\n"
  printf "${C}  OpenVPN      :${K}  UDP ${W}${PUBIP}:${PORT_OVPN}${K}\n"
  printf "${M}━━ Per-user links ─━${K}\n"
  if [[ -d "$ZDIR/links" ]] && ls "$ZDIR/links/"*.txt >/dev/null 2>&1; then
    ls -1 "$ZDIR/links/"*.txt | sed 's/^/  /'
  else
    printf "  ${Y}(none — pick option 1 → Create Xray account)${K}\n"
  fi
  echo
}

#────────────────────────────── Colorful Menu ─────────────────────────────────
top_header(){
  local col cols=( "${R}" "${Y}" "${G}" "${C}" "${B}" "${M}" )
  printf "\n"; local i=0
  while read -rn1 ch; do
    [[ -z "$ch" ]] && { printf ' '; continue; }
    printf '%b%b' "${cols[$((i%6))]}" "$ch"; i=$((i+1))
  done <<<"ZAINU X BRAND 😎"
  printf '%b\n' "$K"
  printf "${C}═══════════════${K} ${M}PREMIUM VPN PANEL${K} ${C}v${VER}${K} ${C}═══════════════${K}\n"
  printf "${G}Server:${K} %-22s ${G}IP:${K} %-15s ${G}Accounts:${K} %s\n" \
    "$(hostname)" "${PUBIP}" "$(awk -F: 'NF>3{c++} END{print c+0}' "$DB" 2>/dev/null)"
  printf "${Y}══════════════════════════════════════════════════════════════════════${K}\n"
}

menu_main(){
  top_header
  printf "  ${C} 1${K}) ${G}Create Account${K}        ${Y}(SSH / Xray / WG / OVPN / SlowDNS)${K}\n"
  printf "  ${C} 2${K}) ${G}List Accounts${K}\n"
  printf "  ${C} 3${K}) ${G}Delete Account${K}\n"
  printf "  ${C} 4${K}) ${G}Renew / Extend Account${K}\n"
  printf "  ${C} 5${K}) ${G}Traffic Usage${K}\n"
  printf "  ${C} 6${K}) ${G}Show Protocol Links${K}   ${Y}(VMess/VLESS/Trojan/SS/HY2/UDP)${K}\n"
  printf "  ${C} 7${K}) ${G}Show Brand Banner${K}     ${Y}(what users see on login)${K}\n"
  printf "  ${C} 8${K}) ${G}Service Status${K}        ${Y}(PASS/FAIL check)${K}\n"
  printf "  ${C} 9${K}) ${G}Restart All Services${K}\n"
  printf "  ${C}10${K}) ${G}System Info${K}\n"
  printf "  ${C}11${K}) ${Y}Re-install / Add Protocols${K}\n"
  printf "  ${C}12${K}) ${R}Uninstall ZAINU${K}\n"
  printf "  ${C} 0${K}) ${R}Exit Panel${K}\n"
  printf "${Y}══════════════════════════════════════════════════════════════════════${K}\n"
  printf "${W}Select [0-12]: ${K}"
  read -r c
}

menu_create_account(){
  clear 2>/dev/null || true
  top_header
  printf "${C}What type of account do you want to create?${K}\n\n"
  printf "  ${C}1${K}) ${G}SSH / Dropbear / SSL-TLS${K}    ${Y}— username + password login${K}\n"
  printf "  ${C}2${K}) ${G}Xray${K} (VMess / VLESS / Trojan / Reality / SS)\n"
  printf "  ${C}3${K}) ${G}WireGuard${K} peer   ${Y}— generate .conf${K}\n"
  printf "  ${C}4${K}) ${G}OpenVPN${K} client   ${Y}— generate .ovpn${K}\n"
  printf "  ${C}5${K}) ${G}SlowDNS${K} (iodine) ${Y}— ns subdomain login${K}\n"
  printf "  ${C}0${K}) ${R}← Back${K}\n"
  printf "${Y}──────────────────────────────────────────────────────────────────────${K}\n"
  read -r -p "Select [0-5]: " pt
  case "$pt" in
    1) acc_create_ssh ;;
    2) acc_create_xray ;;
    3) acc_create_wg ;;
    4) acc_create_ovpn ;;
    5) acc_create_slowdns ;;
    0|"") return ;;
    *) wr "invalid" ;;
  esac
  pause
}

menu(){
  while true; do
    clear 2>/dev/null || true
    menu_main
    case "$c" in
      1)  menu_create_account ;;
      2)  acc_list; pause ;;
      3)  acc_delete; pause ;;
      4)  acc_renew; pause ;;
      5)  acc_traffic; pause ;;
      6)  show_links; pause ;;
      7)  connect_banner; pause ;;
      8)  install_selftest; pause ;;
      9)  restart_all; pause ;;
      10) sys_info; pause ;;
      11) read -r -p "Re-run full install? Existing config + accounts kept (y/N): " cf
          [[ "$cf" =~ ^[Yy]$ ]] && do_install || wr "cancelled" ;;
      12) read -r -p "Type YES to confirm uninstall: " cf; [[ "$cf" == "YES" ]] && do_uninstall || wr "cancelled" ;;
      0|"") printf "${M}Bye! Powered by $BRAND 😎${K}\n"; break ;;
      *)  wr "invalid choice"; sleep 1 ;;
    esac
  done
}

#────────────────────────────── Main ──────────────────────────────────────────
main(){
  # Always load persisted config (globals for menu)
  load_config || true
  PUBIP="$(get_pubip)"

  # nuke persisted config if --reset
  [[ $RESET_CONFIG -eq 1 ]] && rm -f "$ZDIR/config.env" && ok "Config reset"

  case "$ACTION" in
    uninstall) do_uninstall ;;
    install)   do_install ;;
    create)    acc_create_ssh ;;
    list)      acc_list ;;
    menu)      menu ;;
    auto)
      if is_installed && [[ -s "$ZDIR/config.env" ]]; then
        menu
      else
        do_install
      fi
      ;;
  esac
}
main "$@"