#!/bin/bash
#====================================================
#  ZAINI X BRAND PREMIUM VPN SCRIPT
#  Full Uninstaller
#  Removes ALL components so the script can be re-run
#  cleanly from scratch with: bash install.sh
#====================================================

R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
W='\033[1;37m'
N='\033[0m'

echo -e "${Y}=====================================================${N}"
echo -e "${R}    ZAINI X BRAND VPN — FULL UNINSTALL${N}"
echo -e "${Y}=====================================================${N}"
echo ""

#------------- CONFIRM -------------
read -p "This will REMOVE ALL VPN services and configs. Type 'yes' to continue: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${Y}Cancelled.${N}"
    exit 0
fi

echo -e "${W}[1/8] Stopping services...${N}"
for SVC in nginx stunnel4 dropbear xray ssh; do
    systemctl stop "$SVC" 2>/dev/null
    systemctl disable "$SVC" 2>/dev/null
done

echo -e "${W}[2/8] Removing VPN packages...${N}"
apt remove --purge -y stunnel4 dropbear xray nginx certbot python3-certbot-nginx 2>/dev/null
apt autoremove -y 2>/dev/null

echo -e "${W}[3/8] Removing Xray binary...${N}"
systemctl stop xray 2>/dev/null
rm -rf /usr/local/bin/xray /usr/local/etc/xray /var/log/xray /etc/systemd/system/xray* 2>/dev/null
systemctl daemon-reload 2>/dev/null

echo -e "${W}[4/8] Removing SSL certificates...${N}"
rm -rf /etc/nginx/ssl
rm -rf /etc/letsencrypt/live/* /etc/letsencrypt/archive/* /etc/letsencrypt/renewal/*

echo -e "${W}[5/8] Removing config files...${N}"
rm -f /etc/nginx/conf.d/zainix.conf
rm -f /etc/stunnel/stunnel.conf
rm -f /etc/default/dropbear.bak
rm -f /etc/ssh/sshd_config.bak

echo -e "${W}[6/8] Restoring default SSH config...${N}"
cat > /etc/ssh/sshd_config <<'EOF'
Port 22
PermitRootLogin prohibit-password
PasswordAuthentication yes
PubkeyAuthentication yes
EOF
systemctl restart ssh 2>/dev/null

echo -e "${W}[7/8] Removing ZAINIX brand files and users...${N}"
rm -rf /etc/zainix-brand
rm -f /etc/issue.net /etc/motd /etc/banner /etc/dropbear/banner

# Remove all users created by this script (keep system users)
echo -e "${W}    Removing created users...${N}"
if [[ -d /home ]]; then
    for USERDIR in /home/*; do
        U=$(basename "$USERDIR")
        # Skip system users (UID < 1000) and current root/sudo users
        UID_NUM=$(id -u "$U" 2>/dev/null)
        if [[ -n "$UID_NUM" && "$UID_NUM" -ge 1000 ]]; then
            # Only remove if /etc/passwd shows shell is /bin/bash (created by script)
            SHELL_=$(getent passwd "$U" | cut -d: -f7)
            if [[ "$SHELL_" == "/bin/bash" ]]; then
                userdel -r "$U" 2>/dev/null
                echo -e "    ${R}removed user: $U${N}"
            fi
        fi
    done
fi

echo -e "${W}[8/8] Removing menu commands and firewall rules...${N}"
rm -f /usr/local/bin/menu /usr/local/bin/zainix-uninstall
ufw --force reset 2>/dev/null
iptables -F 2>/dev/null
netfilter-persistent save 2>/dev/null

echo ""
echo -e "${G}=====================================================${N}"
echo -e "${G}    UNINSTALL COMPLETE${N}"
echo -e "${G}=====================================================${N}"
echo ""
echo -e "${W}All VPN components, configs, users and certificates${N}"
echo -e "${W}have been removed. Your VPS is now clean.${N}"
echo ""
echo -e "${W}To re-install from scratch, just run:${N}"
echo -e "${G}    bash install.sh${N}"
echo ""
exit 0