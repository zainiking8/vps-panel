#!/bin/bash
#====================================================
#  ZAINI X BRAND PREMIUM VPN SCRIPT
#  100% Deep Clean Uninstaller & Purge System
#====================================================

export DEBIAN_FRONTEND=noninteractive

R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
N='\033[0m'

echo -e "${Y}Starting Full Deep Clean Purge...${N}"

# 1. Stop and Force Mask Services
echo -e "${Y}[1/5] Disabling and stopping all services...${N}"
for SVC in nginx dropbear stunnel4 xray wstunnel-ssh vnstat ufw; do
    systemctl stop "$SVC" 2>/dev/null
    systemctl disable "$SVC" 2>/dev/null
    systemctl mask "$SVC" 2>/dev/null
done

# 2. Reset Firewall Completely
echo -e "${Y}[2/5] Resetting firewall and network tables...${N}"
if command -v ufw &>/dev/null; then
    ufw --force reset 2>/dev/null
    ufw disable 2>/dev/null
fi
iptables -F 2>/dev/null
iptables -X 2>/dev/null
iptables -t nat -F 2>/dev/null
iptables -t nat -X 2>/dev/null

# 3. Restore Default SSH Configuration
echo -e "${Y}[3/5] Restoring original clean SSH configuration...${N}"
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's|Banner /etc/banner||g' /etc/ssh/sshd_config
    sed -i 's|PrintMotd yes|PrintMotd no|g' /etc/ssh/sshd_config
    systemctl unmask ssh 2>/dev/null
    systemctl restart ssh 2>/dev/null
fi

# 4. Remove All Installed Files, Configurations & Binaries
echo -e "${Y}[4/5] Removing folders and systemd definitions...${N}"
rm -rf /etc/zainix-brand
rm -rf /etc/nginx/ssl
rm -f /etc/nginx/conf.d/zainix.conf
rm -rf /usr/local/etc/xray
rm -f /etc/stunnel/stunnel.conf
rm -f /etc/systemd/system/wstunnel-ssh.service
rm -f /usr/local/bin/wstunnel
rm -f /usr/local/bin/menu
rm -f /usr/local/bin/zainix-uninstall

# 5. Clean Environment Banners
echo -e "${Y}[5/5] Resetting MOTD and login banners...${N}"
rm -f /etc/issue.net /etc/motd /etc/banner /etc/dropbear/banner
touch /etc/motd /etc/issue.net
systemctl daemon-reload

echo -e "${G}=====================================================${N}"
echo -e "${G}    PURGE COMPLETE! VPS IS NOW COMPLETELY FRESH!${N}"
echo -e "${G}=====================================================${N}"
echo -e "${Y}Rebooting VPS in 3 seconds to clear locked ports...${N}"
sleep 3
reboot
