#!/usr/bin/env bash
# ============================================================
# ZAINUXBRAND 😎 PREMIUM VPN SCRIPT
# Multi-service VPS panel for authorized server administration
# Ubuntu 22.04 / 24.04 recommended
# ============================================================
set -Eeuo pipefail

SCRIPT_NAME='ZAINUXBRAND 😎 PREMIUM VPN SCRIPT'
SCRIPT_VERSION='4.0.0'
BASE='/etc/zainuxbrand'
SERVERS="$BASE/servers"
USERS="$BASE/users"
SLOWDNS_DIR='/etc/dnstt'
XRAY_CFG='/usr/local/etc/xray/config.json'
NGINX_SITE='/etc/nginx/sites-available/zainuxbrand.conf'
SELF='/usr/local/bin/menu'
BACKUPS='/root/zainuxbrand-backups'
LOG='/var/log/zainuxbrand.log'
UPDATE_URL="${UPDATE_URL:-https://raw.githubusercontent.com/YOUR-GITHUB-USER/YOUR-REPO/main/menu.sh}"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
msg(){ echo -e "${C}[INFO]${N} $*"; }
ok(){ echo -e "${G}[ OK ]${N} $*"; }
warn(){ echo -e "${Y}[WARN]${N} $*"; }
err(){ echo -e "${R}[ERR ]${N} $*"; }
trap 'err "Failed at line $LINENO"' ERR

init(){ mkdir -p "$BASE" "$SERVERS" "$USERS" "$BACKUPS"; touch "$LOG"; chmod 600 "$LOG"; }
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }
root(){ [[ $EUID -eq 0 ]] || { err 'Run as root.'; exit 1; }; }
ubuntu(){ . /etc/os-release; [[ ${ID:-} == ubuntu ]] || { err "Ubuntu required; detected ${PRETTY_NAME:-unknown}"; exit 1; }; }
need(){ command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; return 1; }; }

header(){
 clear
 echo -e "${C}╔══════════════════════════════════════════════════════════════════╗${N}"
 echo -e "${M}║        ${W}ZAINUXBRAND 😎 PREMIUM VPN SCRIPT${N}${M}  v${SCRIPT_VERSION}        ║${N}"
 echo -e "${C}╠══════════════════════════════════════════════════════════════════╣${N}"
 echo -e "${G}║  SSH • UDPGW • SlowDNS • VLESS • VMess • Trojan • REALITY      ║${N}"
 echo -e "${G}║  WS • TLS • gRPC • TCP • SSL • Nginx • Client Configs          ║${N}"
 echo -e "${C}╚══════════════════════════════════════════════════════════════════╝${N}"
}

install_packages(){
 root; init; export DEBIAN_FRONTEND=noninteractive
 apt-get update -y
 local p; local pkgs=(curl wget ca-certificates unzip jq openssl nginx certbot python3-certbot-nginx ufw dnsutils git golang-go build-essential cmake iptables)
 : > "$BASE/packages.new"
 for p in "${pkgs[@]}"; do
   if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed'; then echo "$p" >> "$BASE/packages.new"; fi
 done
 apt-get install -y "${pkgs[@]}"
 cat "$BASE/packages.new" >> "$BASE/packages" 2>/dev/null || true
 sort -u "$BASE/packages" -o "$BASE/packages" 2>/dev/null || true
 rm -f "$BASE/packages.new"
 ok 'System dependencies installed.'
}

system_update(){ root; export DEBIAN_FRONTEND=noninteractive; apt-get update -y; apt-get upgrade -y; apt-get autoremove -y; ok 'System updated.'; }

server_ip(){ SERVER_IP="$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"; [[ -n $SERVER_IP ]] || SERVER_IP='unknown'; echo "$SERVER_IP" > "$BASE/server_ip"; }
load_domain(){ if [[ -f $BASE/domain ]]; then DOMAIN="$(cat "$BASE/domain")"; else domain_setup; fi; }
domain_setup(){
 root; init; server_ip; read -rp 'Main SSL/Xray domain (e.g. vpn.example.com): ' DOMAIN; DOMAIN="${DOMAIN,,}"; [[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || { err 'Invalid domain.'; return 1; }; echo "$DOMAIN" > "$BASE/domain"
 local ip; ip="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"; [[ -z $ip ]] && warn 'DNS does not resolve yet.' || { echo "DNS: $ip"; [[ $ip == "$SERVER_IP" ]] && ok 'A record matches VPS.' || warn "A record is $ip, VPS is $SERVER_IP"; }
}

ssl_ready(){ load_domain; [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; }
setup_ssl(){
 root; install_packages >/dev/null; load_domain
 mkdir -p /var/www/html
 cat > "$NGINX_SITE" <<EOF2
server { listen 80; listen [::]:80; server_name $DOMAIN; root /var/www/html; location /.well-known/acme-challenge/ { try_files \$uri =404; } location / { return 200 'ZAINUXBRAND 😎 PREMIUM VPN SCRIPT'; add_header Content-Type text/plain; } }
EOF2
 ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/zainuxbrand.conf; rm -f /etc/nginx/sites-enabled/default; nginx -t; systemctl enable --now nginx
 certbot certonly --webroot -w /var/www/html -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || { warn 'SSL failed. DNS and TCP/80 must reach this VPS.'; return 1; }
 ok "Let's Encrypt certificate ready for $DOMAIN"; systemctl enable --now certbot.timer 2>/dev/null || true
}

xray_install(){
 root; install_packages >/dev/null
 if ! command -v xray >/dev/null 2>&1; then
   bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
 fi
 command -v xray >/dev/null 2>&1 || { err 'Xray installation failed.'; return 1; }
}

xray_init(){
 xray_install; mkdir -p /usr/local/etc/xray
 if [[ ! -f $XRAY_CFG ]]; then echo '{"log":{"loglevel":"warning"},"inbounds":[],"outbounds":[{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]}' > "$XRAY_CFG"; fi
}

add_inbound(){
 local json="$1" tag="$2"; [[ -n $tag ]] || return 1
 jq --arg tag "$tag" --argjson item "$json" 'del(.inbounds[] | select(.tag==$tag)) | .inbounds += [$item]' "$XRAY_CFG" > "$XRAY_CFG.tmp"
 mv "$XRAY_CFG.tmp" "$XRAY_CFG"
}
remove_inbound(){ local tag="$1"; jq --arg tag "$tag" 'del(.inbounds[] | select(.tag==$tag))' "$XRAY_CFG" > "$XRAY_CFG.tmp"; mv "$XRAY_CFG.tmp" "$XRAY_CFG"; }

nginx_rebuild(){
 load_domain; ssl_ready || { warn 'SSL certificate missing; install SSL first.'; return 1; }
 cat > "$NGINX_SITE" <<EOF2
server {
 listen 80; listen [::]:80; server_name $DOMAIN;
 location /.well-known/acme-challenge/ { root /var/www/html; }
 location / { return 200 'ZAINUXBRAND 😎 PREMIUM VPN SCRIPT'; add_header Content-Type text/plain; }
}
server {
 listen 443 ssl http2; listen [::]:443 ssl http2; server_name $DOMAIN;
 ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
 ssl_protocols TLSv1.2 TLSv1.3;
 add_header Strict-Transport-Security 'max-age=31536000' always;
EOF2
 [[ -f $SERVERS/vless_ws ]] && cat >> "$NGINX_SITE" <<'EOF2'
 location /vlessws { proxy_redirect off; proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
EOF2
 [[ -f $SERVERS/vmess_ws ]] && cat >> "$NGINX_SITE" <<'EOF2'
 location /vmessws { proxy_redirect off; proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
EOF2
 [[ -f $SERVERS/trojan_ws ]] && cat >> "$NGINX_SITE" <<'EOF2'
 location /trojanws { proxy_redirect off; proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
EOF2
 [[ -f $SERVERS/vless_grpc ]] && cat >> "$NGINX_SITE" <<'EOF2'
 location ^~ /vless-grpc { grpc_pass grpc://127.0.0.1:10004; }
EOF2
 cat >> "$NGINX_SITE" <<'EOF2'
}
EOF2
 ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/zainuxbrand.conf; rm -f /etc/nginx/sites-enabled/default
 nginx -t; systemctl enable --now nginx; systemctl restart nginx
 ok 'Nginx reverse-proxy configuration rebuilt.'
}

apply_xray(){
 xray_init
 xray run -test -config "$XRAY_CFG"
 systemctl enable xray >/dev/null 2>&1 || true
 systemctl restart xray
 nginx_rebuild 2>/dev/null || true
 ok 'Xray configuration validated and service restarted.'
}

create_vless_ws(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local uuid; uuid="$(xray uuid)"; echo "$uuid" > "$SERVERS/vless_ws.uuid"
 local j; j="$(jq -nc --arg uuid "$uuid" '{listen:"127.0.0.1",port:10001,tag:"vless-ws",protocol:"vless",settings:{clients:[{id:$uuid,level:0}],decryption:"none"},streamSettings:{network:"ws",security:"none",wsSettings:{path:"/vlessws"}}}')"
 add_inbound "$j" vless-ws; touch "$SERVERS/vless_ws"; apply_xray
 echo "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&sni=$DOMAIN&path=%2Fvlessws#ZAINUX-VLESS-WS" | tee "$SERVERS/vless_ws.txt"; ok 'VLESS WebSocket + TLS created.'
}

create_vmess_ws(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local uuid; uuid="$(xray uuid)"; echo "$uuid" > "$SERVERS/vmess_ws.uuid"
 local j; j="$(jq -nc --arg uuid "$uuid" '{listen:"127.0.0.1",port:10002,tag:"vmess-ws",protocol:"vmess",settings:{clients:[{id:$uuid,alterId:0,level:0}]},streamSettings:{network:"ws",security:"none",wsSettings:{path:"/vmessws"}}}')"
 add_inbound "$j" vmess-ws; touch "$SERVERS/vmess_ws"; apply_xray
 local vm; vm="$(jq -nc --arg v "$DOMAIN" --arg id "$uuid" '{v:"2",ps:"ZAINUX-VMESS-WS",add:$v,port:"443",id:$id,aid:"0",scy:"auto",net:"ws",type:"none",host:$v,path:"/vmessws",tls:"tls",sni:$v} ' | base64 -w0)"; echo "vmess://$vm" | tee "$SERVERS/vmess_ws.txt"; ok 'VMess WebSocket + TLS created.'
}

create_trojan_ws(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local pass; pass="$(openssl rand -hex 16)"; echo "$pass" > "$SERVERS/trojan_ws.password"
 local j; j="$(jq -nc --arg pass "$pass" '{listen:"127.0.0.1",port:10003,tag:"trojan-ws",protocol:"trojan",settings:{clients:[{password:$pass,level:0}]},streamSettings:{network:"ws",security:"none",wsSettings:{path:"/trojanws"}}}')"
 add_inbound "$j" trojan-ws; touch "$SERVERS/trojan_ws"; apply_xray
 echo "trojan://$pass@$DOMAIN:443?security=tls&type=ws&host=$DOMAIN&sni=$DOMAIN&path=%2Ftrojanws#ZAINUX-TROJAN-WS" | tee "$SERVERS/trojan_ws.txt"; ok 'Trojan WebSocket + TLS created.'
}

create_vless_grpc(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local uuid; uuid="$(xray uuid)"; echo "$uuid" > "$SERVERS/vless_grpc.uuid"
 local j; j="$(jq -nc --arg uuid "$uuid" '{listen:"127.0.0.1",port:10004,tag:"vless-grpc",protocol:"vless",settings:{clients:[{id:$uuid}],decryption:"none"},streamSettings:{network:"grpc",security:"none",grpcSettings:{serviceName:"vless-grpc"}}}')"
 add_inbound "$j" vless-grpc; touch "$SERVERS/vless_grpc"; apply_xray
 echo "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=grpc&serviceName=vless-grpc&sni=$DOMAIN#ZAINUX-VLESS-gRPC" | tee "$SERVERS/vless_grpc.txt"; ok 'VLESS gRPC + TLS created.'
}

create_vless_tcp_tls(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local uuid; uuid="$(xray uuid)"; echo "$uuid" > "$SERVERS/vless_tcp.uuid"
 local j; j="$(jq -nc --arg uuid "$uuid" '{listen:"0.0.0.0",port:2053,tag:"vless-tcp-tls",protocol:"vless",settings:{clients:[{id:$uuid}],decryption:"none"},streamSettings:{network:"raw",security:"tls",tlsSettings:{certificates:[{certificateFile:"/etc/letsencrypt/live/DOMAIN/fullchain.pem",keyFile:"/etc/letsencrypt/live/DOMAIN/privkey.pem"}]}}}')"; j="${j//DOMAIN/$DOMAIN}"
 add_inbound "$j" vless-tcp-tls; touch "$SERVERS/vless_tcp"; apply_xray
 echo "vless://$uuid@$DOMAIN:2053?encryption=none&security=tls&type=tcp&sni=$DOMAIN#ZAINUX-VLESS-TCP-TLS" | tee "$SERVERS/vless_tcp.txt"; ok 'VLESS TCP + TLS created on 2053.'
}

create_trojan_tls(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local pass; pass="$(openssl rand -hex 16)"; echo "$pass" > "$SERVERS/trojan_tls.password"
 local j; j="$(jq -nc --arg pass "$pass" '{listen:"0.0.0.0",port:8443,tag:"trojan-tls",protocol:"trojan",settings:{clients:[{password:$pass}]},streamSettings:{network:"raw",security:"tls",tlsSettings:{certificates:[{certificateFile:"/etc/letsencrypt/live/DOMAIN/fullchain.pem",keyFile:"/etc/letsencrypt/live/DOMAIN/privkey.pem"}]}}}')"; j="${j//DOMAIN/$DOMAIN}"
 add_inbound "$j" trojan-tls; touch "$SERVERS/trojan_tls"; apply_xray
 echo "trojan://$pass@$DOMAIN:8443?security=tls&sni=$DOMAIN&type=tcp#ZAINUX-TROJAN-TLS" | tee "$SERVERS/trojan_tls.txt"; ok 'Trojan TLS created on 8443.'
}

create_vmess_tcp_tls(){
 xray_init; load_domain; ssl_ready || { err 'Install SSL first.'; return 1; }
 local uuid; uuid="$(xray uuid)"; echo "$uuid" > "$SERVERS/vmess_tcp.uuid"
 local j; j="$(jq -nc --arg uuid "$uuid" '{listen:"0.0.0.0",port:2083,tag:"vmess-tcp-tls",protocol:"vmess",settings:{clients:[{id:$uuid,alterId:0}]},streamSettings:{network:"raw",security:"tls",tlsSettings:{certificates:[{certificateFile:"/etc/letsencrypt/live/DOMAIN/fullchain.pem",keyFile:"/etc/letsencrypt/live/DOMAIN/privkey.pem"}]}}}')"; j="${j//DOMAIN/$DOMAIN}"
 add_inbound "$j" vmess-tcp-tls; touch "$SERVERS/vmess_tcp"; apply_xray
 local vm; vm="$(jq -nc --arg v "$DOMAIN" --arg id "$uuid" '{v:"2",ps:"ZAINUX-VMESS-TCP-TLS",add:$v,port:"2083",id:$id,aid:"0",scy:"auto",net:"tcp",type:"none",tls:"tls",sni:$v}' | base64 -w0)"; echo "vmess://$vm" | tee "$SERVERS/vmess_tcp.txt"; ok 'VMess TCP + TLS created on 2083.'
}

create_reality(){
 xray_init; load_domain
 local port target sni; read -rp 'REALITY port [default 2087]: ' port; port="${port:-2087}"; read -rp 'REALITY target SNI [default www.cloudflare.com]: ' sni; sni="${sni:-www.cloudflare.com}"; target="$sni:443"
 local keys priv pub uuid sid; keys="$(xray x25519 2>/dev/null)"; priv="$(echo "$keys" | awk -F': ' '/Private key/{print $2; exit}')"; pub="$(echo "$keys" | awk -F': ' '/Public key/{print $2; exit}')"; [[ -n $priv && -n $pub ]] || { err 'Could not generate X25519 keys.'; return 1; }; sid="$(openssl rand -hex 4)"; uuid="$(xray uuid)"
 echo "$priv" > "$SERVERS/reality.private"; chmod 600 "$SERVERS/reality.private"; printf '%s\n%s\n%s\n%s\n%s\n' "$pub" "$sid" "$uuid" "$sni" "$port" > "$SERVERS/reality.info"
 local j; j="$(jq -nc --arg uuid "$uuid" --arg priv "$priv" --arg sni "$sni" --arg sid "$sid" --argjson port "$port" '{listen:"0.0.0.0",port:$port,tag:"vless-reality",protocol:"vless",settings:{clients:[{id:$uuid}],decryption:"none"},streamSettings:{network:"raw",security:"reality",realitySettings:{show:false,dest:($sni+":443"),xver:0,serverNames:[$sni],privateKey:$priv,shortIds:[$sid]}}}')"
 add_inbound "$j" vless-reality; touch "$SERVERS/reality"; apply_xray
 echo "vless://$uuid@$DOMAIN:$port?encryption=none&security=reality&type=tcp&sni=$sni&fp=chrome&pbk=$pub&sid=$sid#ZAINUX-VLESS-REALITY" | tee "$SERVERS/reality.txt"; ok "VLESS REALITY created on $port."
}

xray_menu(){
 while true; do
  echo; echo -e "${M}========== XRAY SERVER CREATOR ==========${N}"
  echo '1) VLESS + WebSocket + TLS (443)'
  echo '2) VMess + WebSocket + TLS (443)'
  echo '3) Trojan + WebSocket + TLS (443)'
  echo '4) VLESS + gRPC + TLS (443)'
  echo '5) VLESS + TCP + TLS (2053)'
  echo '6) VMess + TCP + TLS (2083)'
  echo '7) Trojan + TCP + TLS (8443)'
  echo '8) VLESS + REALITY (custom port)'
  echo '9) Show all Xray configs/links'
  echo '10) Rebuild + restart all Xray/Nginx'
  echo '0) Back'
  read -rp 'Select: ' n
  case $n in 1) create_vless_ws;;2)create_vmess_ws;;3)create_trojan_ws;;4)create_vless_grpc;;5)create_vless_tcp_tls;;6)create_vmess_tcp_tls;;7)create_trojan_tls;;8)create_reality;;9)show_xray_configs;;10)apply_xray;;0)return;;*)warn 'Invalid.';;esac
  read -rp 'Press Enter... ' _
 done
}

show_xray_configs(){
 echo; echo -e "${C}================ XRAY CONNECTIONS ================${N}"
 for f in "$SERVERS"/*.txt; do [[ -f $f ]] || continue; echo; echo -e "${Y}$(basename "$f")${N}"; cat "$f"; done
 [[ -f $XRAY_CFG ]] && echo; jq -r '.inbounds[]? | [.tag,.protocol,.listen,.port] | @tsv' "$XRAY_CFG" 2>/dev/null | column -t || true
}

open_ports(){
 root
 install_packages >/dev/null
 for p in 80/tcp 443/tcp 53/udp 53/tcp 2053/tcp 2083/tcp 2087/tcp 8443/tcp; do ufw allow "$p" >/dev/null 2>&1 || true; done
 ok 'Required public ports allowed in UFW (if UFW is enabled).'
}

slowdns_install(){
 root; install_packages >/dev/null
 local zone ns sshport; load_domain; server_ip
 read -rp 'SlowDNS tunnel zone (e.g. t.example.com): ' zone
 read -rp 'Nameserver host (e.g. ns1.example.com): ' ns
 [[ -n $zone && -n $ns ]] || { err 'Both zone and NS host are required.'; return 1; }
 sshport="$(ss -ltnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}')"; sshport="${sshport:-22}"
 local tmp=/tmp/dnstt-build-$$; rm -rf "$tmp"; git clone --depth 1 https://github.com/getlantern/dnstt.git "$tmp" >/dev/null 2>&1 || { err 'DNSTT source download failed.'; return 1; }
 (cd "$tmp/server" && go build -o "$tmp/dnstt-server" .) || { rm -rf "$tmp"; err 'DNSTT build failed.'; return 1; }
 install -m 755 "$tmp/dnstt-server" /usr/local/bin/dnstt-server; rm -rf "$tmp"
 mkdir -p "$SLOWDNS_DIR"; if [[ ! -f $SLOWDNS_DIR/server.key ]]; then /usr/local/bin/dnstt-server -gen-key -privkey-file "$SLOWDNS_DIR/server.key" -pubkey-file "$SLOWDNS_DIR/server.pub"; fi; chmod 600 "$SLOWDNS_DIR/server.key"; 
 cat > /etc/systemd/system/dnstt-server.service <<EOF2
[Unit]
Description=ZAINUXBRAND SlowDNS SSH tunnel
After=network-online.target ssh.service
Wants=network-online.target
[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey-file $SLOWDNS_DIR/server.key $zone 127.0.0.1:$sshport
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF2
 systemctl daemon-reload; systemctl enable --now dnstt-server
 iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
 echo "$zone" > "$BASE/slowdns.zone"; echo "$ns" > "$BASE/slowdns.ns"; echo "$sshport" > "$BASE/slowdns.sshport"
 ufw allow 53/udp >/dev/null 2>&1 || true
 ok 'SlowDNS SSH server active.'
 echo; echo "A  $ns  -> $SERVER_IP"; echo "NS $zone -> $ns"; echo "Public key:"; cat "$SLOWDNS_DIR/server.pub"; echo "SSH upstream: 127.0.0.1:$sshport"; echo "Client apps: use DNSTT client with the public key and your DNS resolver."
}
slowdns_status(){ systemctl --no-pager --full status dnstt-server 2>/dev/null || true; }

badvpn_install(){
 root; install_packages >/dev/null
 if [[ ! -x /usr/local/bin/badvpn-udpgw ]]; then
   local tmp=/tmp/badvpn-$$; rm -rf "$tmp"; git clone --depth 1 https://github.com/ambrop72/badvpn.git "$tmp" >/dev/null 2>&1 || { err 'BadVPN source download failed.'; return 1; }
   mkdir -p "$tmp/build"; (cd "$tmp/build" && cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null && make -j"$(nproc)" >/dev/null) || { rm -rf "$tmp"; err 'BadVPN build failed.'; return 1; }
   install -m 755 "$tmp/build/udpgw/badvpn-udpgw" /usr/local/bin/badvpn-udpgw; rm -rf "$tmp"
 fi
 cat > /etc/systemd/system/badvpn-udpgw.service <<'EOF2'
[Unit]
Description=ZAINUXBRAND BadVPN UDP Gateway
After=network.target
[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --loglevel none --listen-addr 127.0.0.1:7300 --max-clients 999
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF2
 systemctl daemon-reload; systemctl enable --now badvpn-udpgw
 echo 7300 > "$BASE/badvpn.port"; ok 'BadVPN UDPGW active on 127.0.0.1:7300.'
}

ssh_setup(){
 root; install_packages >/dev/null; systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || true
 local port; port="$(ss -ltnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}')"; echo "${port:-22}" > "$BASE/ssh.port"
 mkdir -p /etc/ssh/sshd_config.d; cat > /etc/ssh/sshd_config.d/zainuxbrand.conf <<'EOF2'
AllowTcpForwarding yes
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3
EOF2
 sshd -t && systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
 ok "SSH ready on port $(cat "$BASE/ssh.port")"
}

randpass(){ openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 12; echo; }
create_ssh_user(){
 ssh_setup; read -rp 'Username: ' u; [[ $u =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { err 'Invalid username.'; return 1; }; id "$u" >/dev/null 2>&1 && { warn 'User already exists.'; return 1; }
 read -rp 'Password (blank = generate): ' p; p="${p:-$(randpass)}"; read -rp 'Concurrent login/IP limit [1]: ' lim; lim="${lim:-1}"; read -rp 'Expiry days [30]: ' days; days="${days:-30}"
 useradd -m -s /bin/bash "$u"; echo "$u:$p" | chpasswd; local exp; exp="$(date -d "+$days days" +%s)"; mkdir -p "$USERS/$u"; printf 'USERNAME=%q\nPASSWORD=%q\nEXPIRY_TS=%q\nIP_LIMIT=%q\n' "$u" "$p" "$exp" "$lim" > "$USERS/$u/info"; echo "* hard maxlogins $lim" > "/etc/security/limits.d/zainuxbrand-$u.conf"
 echo; echo -e "${G}========== SSH ACCOUNT ===========${N}"; echo "Host: $(cat "$BASE/ssh.port" >/dev/null; server_ip; echo "$SERVER_IP")"; echo "Port: $(cat "$BASE/ssh.port")"; echo "User: $u"; echo "Pass: $p"; echo "Expires: $(date -d @$exp '+%F %T')"; echo "Concurrent logins: $lim"; echo -e "${Y}Payload template:${N}"; echo 'CONNECT [host_port] HTTP/1.1[crlf]Host: [host][crlf]Connection: keep-alive[crlf][crlf]'; ok "SSH user $u created."; log "Created SSH user $u";
}
delete_ssh_user(){ read -rp 'Username to delete: ' u; [[ $u != root ]] || { err 'Cannot delete root.'; return 1; }; id "$u" >/dev/null 2>&1 && userdel -r "$u" || true; rm -rf "$USERS/$u" /etc/security/limits.d/zainuxbrand-$u.conf; ok 'SSH user removed.'; }
list_ssh_users(){ echo -e "${C}================ SSH USERS ================${N}"; for d in "$USERS"/*; do [[ -f $d/info ]] || continue; unset USERNAME PASSWORD EXPIRY_TS IP_LIMIT; source "$d/info"; echo "$USERNAME | expires $(date -d @$EXPIRY_TS '+%F') | maxlogins $IP_LIMIT"; done; }
expire_users(){ local now=$(date +%s); for d in "$USERS"/*; do [[ -f $d/info ]] || continue; unset USERNAME EXPIRY_TS; source "$d/info"; if [[ ${EXPIRY_TS:-0} =~ ^[0-9]+$ && $EXPIRY_TS -le $now ]]; then passwd -l "$USERNAME" >/dev/null 2>&1 || true; fi; done; }

connection_info(){
 load_domain; server_ip; echo; echo -e "${C}╔════════════════ COMPLETE CONNECTION INFO ════════╗${N}"; echo "IP: $SERVER_IP"; echo "Domain: $DOMAIN"; echo "SSH port: $(cat "$BASE/ssh.port" 2>/dev/null || echo 22)"; echo "BadVPN UDPGW: $(cat "$BASE/badvpn.port" 2>/dev/null || echo not-installed)"; echo; show_xray_configs; if [[ -f $BASE/slowdns.zone ]]; then echo; echo "SlowDNS zone: $(cat "$BASE/slowdns.zone")"; echo "NS host: $(cat "$BASE/slowdns.ns")"; echo 'Public key:'; cat "$SLOWDNS_DIR/server.pub"; fi; echo; echo -e "${Y}HTTP payload template (app-specific):${N}"; echo 'CONNECT [host_port] HTTP/1.1[crlf]Host: [host][crlf]Connection: keep-alive[crlf][crlf]'; }

status_all(){ echo -e "${C}================ SERVICES ================${N}"; for s in nginx xray dnstt-server badvpn-udpgw; do echo; echo "--- $s ---"; systemctl is-active "$s" 2>/dev/null || echo inactive; done; ss -lntup 2>/dev/null | grep -E ':(22|53|443|2053|2083|2087|7300|8443)\b' || true; }

backup(){ local t; t=$(date +%Y%m%d-%H%M%S); mkdir -p "$BACKUPS/$t"; cp -a "$BASE" "$BACKUPS/$t/" 2>/dev/null || true; cp -a "$XRAY_CFG" "$BACKUPS/$t/" 2>/dev/null || true; cp -a "$NGINX_SITE" "$BACKUPS/$t/" 2>/dev/null || true; cp -a "$SLOWDNS_DIR" "$BACKUPS/$t/" 2>/dev/null || true; ok "Backup: $BACKUPS/$t"; }

self_update(){
 root; local url="$UPDATE_URL" tmp; [[ "$url" != *YOUR-GITHUB-USER* && "$url" != *YOUR-REPO* ]] || { err 'Set UPDATE_URL to your GitHub RAW menu.sh URL.'; return 1; }; tmp=$(mktemp); curl -fL "$url" -o "$tmp"; head -n1 "$tmp" | grep -q bash || { rm -f "$tmp"; err 'Downloaded file is not a bash script.'; return 1; }; bash -n "$tmp"; install -m755 "$tmp" "$SELF"; rm -f "$tmp"; ok 'Panel updated.'; exec "$SELF";
}

uninstall(){
 root; echo -e "${R}This removes ZAINUXBRAND-owned services/configs. It does not factory-reset Ubuntu.${N}"; read -rp 'Type DELETE: ' c; [[ $c == DELETE ]] || return 0
 local package_file=/tmp/zainuxbrand-packages.$$
 [[ -f "$BASE/packages" ]] && cp "$BASE/packages" "$package_file" || true
 systemctl disable --now dnstt-server badvpn-udpgw xray nginx 2>/dev/null || true
 rm -f /etc/systemd/system/dnstt-server.service /etc/systemd/system/badvpn-udpgw.service; systemctl daemon-reload
 rm -f "$NGINX_SITE" /etc/nginx/sites-enabled/zainuxbrand.conf; rm -rf "$BASE" "$BACKUPS" /etc/dnstt /usr/local/etc/xray; rm -f /usr/local/bin/dnstt-server /usr/local/bin/badvpn-udpgw /etc/ssh/sshd_config.d/zainuxbrand.conf /etc/security/limits.d/zainuxbrand-*.conf
 if [[ -s "$package_file" ]]; then xargs -r apt-get purge -y < "$package_file" || true; apt-get autoremove -y || true; rm -f "$package_file"; fi
 rm -f "$SELF"; ok 'Panel cleanup completed.'; exit 0
}

auto_setup(){
 install_packages; open_ports;  server_ip; domain_setup; setup_ssl; ssh_setup; create_vless_ws; create_vmess_ws; create_trojan_ws; create_vless_grpc; create_vless_tcp_tls; create_vmess_tcp_tls; create_trojan_tls; create_reality; slowdns_install; badvpn_install; connection_info; ok 'Full stack installation sequence completed.';
}

main(){ root; ubuntu; init; if [[ ${1:-} == --expire-check ]]; then expire_users; exit 0; fi; if [[ ${1:-} == --install ]]; then auto_setup; exit 0; fi
 while true; do
  header
  echo -e "${Y} 01${N} System update / dependencies"
  echo -e "${Y} 02${N} Domain + Nginx"
  echo -e "${Y} 03${N} SSL / Let's Encrypt"
  echo -e "${M} 04${N} XRAY: all server creator submenu"
  echo -e "${G} 05${N} SlowDNS SSH + UDP/53"
  echo -e "${G} 06${N} BadVPN UDPGW 7300"
  echo -e "${G} 07${N} SSH user + password + expiry"
  echo -e "${G} 08${N} Delete SSH user"
  echo -e "${G} 09${N} List SSH users"
  echo -e "${C} 10${N} Complete connection / payload info"
  echo -e "${C} 11${N} All service status / ports"
  echo -e "${C} 12${N} Backup configuration"
  echo -e "${C} 13${N} Expiry check"
  echo -e "${C} 14${N} Auto-update panel from GitHub"
  echo -e "${R} 15${N} UNINSTALL / CLEAN PANEL"
  echo -e "${W} 16${N} FULL AUTO SETUP — install everything one-by-one"
  echo -e "${W} 00${N} Exit"
  echo
  read -rp 'Select option: ' n
  case $n in
   1) system_update; install_packages;; 2) domain_setup; setup_ssl || true; open_ports; nginx_rebuild 2>/dev/null || true;; 3) setup_ssl; open_ports; nginx_rebuild 2>/dev/null || true;; 4) xray_menu;; 5) slowdns_install;; 6) badvpn_install;; 7) create_ssh_user;; 8) delete_ssh_user;; 9) list_ssh_users;; 10) connection_info;; 11) status_all;; 12) backup;; 13) expire_users; ok 'Expiry check complete.';; 14) self_update;; 15) uninstall;; 16) auto_setup;; 00|0) exit 0;; *) warn 'Invalid option.';; esac
  echo; read -rp 'Press Enter to continue...' _
 done
}
main "$@"
