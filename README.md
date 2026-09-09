# 🚀 Zainuxbrand VPN Panel

<p align="center">
  <b>👑 ZAINU X BRAND PREMIUM VPN SCRIPT 👑</b><br>
  <i>One script to rule them all — SSH, Xray, SlowDNS, UDP & SSL</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-3.0.0-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/Bash-100%25-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-orange?style=for-the-badge">
</p>

---

## 🌟 Features

| Service | Status |
|---------|--------|
| 🔐 SSH Accounts (IP/GB/Expiry limits) | ✅ |
| 🌐 Xray Core + 3X-UI Panel | ✅ |
| 🔵 VLESS + WebSocket + TLS | ✅ |
| 🟣 Vmess + WebSocket + TLS | ✅ |
| 🟠 Trojan + TLS | ✅ |
| 🟡 Shadowsocks + Reality | ✅ |
| 🐌 SlowDNS Server | ✅ |
| 📡 UDP Custom Tunnel | ✅ |
| 🔒 Let's Encrypt SSL + Nginx | ✅ |
| 🎨 Server Message on Connect | ✅ |
| ⚡ BBR + System Optimization | ✅ |
| 🛡️ Firewall Auto-Config | ✅ |

---

## 🚨 Installation Link

Run this command as **root** on your VPS:

```bash
apt update && apt install -y curl && curl -o /usr/local/bin/menu https://raw.githubusercontent.com/zainiking8/vps-panel/main/menu.sh && chmod +x /usr/local/bin/menu && menu
```

> ⚠️ **Make sure your domain DNS A-records point to your VPS IP before installing SSL.**
> - `panel.yourdomain.com` → VPS IP
> - `sub.yourdomain.com` → VPS IP
> - `vless.yourdomain.com` → VPS IP

---

## 📋 Menu Options

After installation, run:

```bash
menu
```

| Option | Description |
|--------|-------------|
| 1 | Create SSH Account |
| 2 | Delete SSH Account |
| 3 | List SSH Accounts |
| 4 | Generate VLESS Config |
| 5 | Generate Vmess Config |
| 6 | Generate Trojan Config |
| 7 | Edit Server Message |
| 8 | System Info |
| 9 | Reboot Server |
| 10 | Uninstall Panel (Fresh Clean) |
| 0 | Exit |

---

## 🎨 Server Message Example

When any user connects to the VPN, they will see:

```
╔══════════════════════════════════════════════════════════╗
║  👑 ZAINU X BRAND PREMIUM VPN SCRIPT 👑                ║
║                                                          ║
║  ✅ No Hacking    ✅ No Torrent                         ║
║  ✅ No Carding    ✅ No Spam                            ║
║  ✅ No DDoS       ✅ No Illegal Activities              ║
║                                                          ║
║  Thank you for choosing ZAINU X BRAND!                   ║
╚══════════════════════════════════════════════════════════╝
```

---

## 🧹 Uninstall

To completely remove the panel and **fresh-clean your VPS**, run `menu` and select option **10 (Uninstall Panel)**. This will:

- Stop & remove 3X-UI, Xray, SlowDNS, UDP Custom
- Remove Nginx configs & Let's Encrypt SSL certificates
- Delete all SSH accounts created by the panel
- Remove banners, MOTD, SSH banner
- Reset firewall rules
- Revert BBR & system optimizations
- Purge installed packages
- Remove all panel files & the `menu` command

After uninstall, the VPS is **completely clean** and ready for a fresh install.

---

## 🔧 Supported Protocols

- **SSH** — Direct + SSL + WebSocket
- **VLESS** — WebSocket / gRPC / Reality / XTLS-Vision
- **Vmess** — WebSocket / TCP / gRPC
- **Trojan** — TCP + TLS
- **Shadowsocks** — AEAD / Reality
- **SlowDNS** — DNS tunnel over UDP 5300
- **UDP Custom** — UDP to SSH tunnel on port 7300

---

## ⚠️ Terms of Service

- ❌ No Hacking
- ❌ No Torrent
- ❌ No Carding
- ❌ No Spam
- ❌ No DDoS
- ❌ No Illegal Activities

By using this script, you agree to use it for **legal purposes only**.

---

## 👤 Author

**ZAINU X BRAND**

- GitHub: [@zainiking8](https://github.com/zainiking8)
- Project: [vps-panel](https://github.com/zainiking8/vps-panel)

---

<p align="center">
  <b>👑 Stay Connected. Stay Premium. ZAINU X BRAND. 👑</b>
</p>
