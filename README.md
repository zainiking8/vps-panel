# 🚀 Zainuxbrand VPN Panel

<p align="center">
<img src="https://img.shields.io/badge/VERSION-3.0.0-blue?style=for-the-badge"/>
<img src="https://img.shields.io/badge/BASH-100%25-green?style=for-the-badge&logo=gnu-bash&logoColor=white"/>
</p>

> 👑 **ZAINU X BRAND PREMIUM VPN SCRIPT** 👑
> *One script to rule them all — SSH, Xray, SlowDNS, UDP & SSL*

A complete, all-in-one VPN setup script for any VPS. Installs SSH, SSL, WebSocket Dropbear, VLESS WS (TLS & non-TLS), with a branded server banner.

**Server Banner shown on connect:**
```
=====================================================
      WELCOME TO ZAINUXBRAND VIP VPN
   - NO TORRENT / NO MULTILOGIN -
=====================================================
```

---

## ✨ Features

- ✅ OpenSSH + Dropbear (ports 22, 109, 110)
- ✅ SSL via Stunnel (port 443)
- ✅ VLESS WS/TLS + VLESS WS non-TLS (Xray-core)
- ✅ Nginx reverse proxy with Let's Encrypt / self-signed SSL
- ✅ SSH-over-WebSocket via wstunnel (DarkTunnel compatible)
- ✅ Custom banner: **WELCOME TO ZAINUXBRAND VIP VPN**
- ✅ Account creator (Host, Domain, IP, Limit, GB-Limit, User, Pass, Expiry)
- ✅ DarkTunnel payload pre-filled with brand
- ✅ Full uninstall (clean re-install supported)
- ✅ Menu panel — type `menu` anytime

---

## 📦 Installation

### One-line install (recommended)

```bash
apt update && apt install -y curl wget git && bash <(curl -fsSL https://raw.githubusercontent.com/zainiking8/vps-panel/main/install.sh)
```

### Step-by-step install

```bash
apt update && apt install -y curl
curl -o /root/install.sh https://raw.githubusercontent.com/zainiking8/vps-panel/main/install.sh
chmod +x /root/install.sh
bash /root/install.sh
```

> **Note:** This single command installs *all* VPN services, certificates and configs.
> It will automatically fetch `menu.sh` and `uninstall.sh` from this repo.

---

## 🎛️ Menu

After install, just type:

```bash
menu
```

| # | Option |
|---|--------|
| 1 | Create SSH / SSL Account |
| 2 | Create VLESS Account |
| 3 | Create Trial Account (24h) |
| 4 | Delete User |
| 5 | Extend User Validity |
| 6 | Lock User |
| 7 | Unlock User |
| 8 | List All Users |
| 9 | Show Connection Info / Payloads |
| 10 | SSL Certificate Info |
| 11 | Service Status |
| 12 | Restart Services |
| 13 | Bandwidth Usage |
| 14 | System Info |
| 15 | Preview Server Banner |
| 16 | Update Script |
| 17 | Uninstall (full clean) |
| 0 | Exit |

---

## 🔌 Ports

| Port | Service |
|------|---------|
| 22 | OpenSSH |
| 80 | Nginx HTTP / VLESS WS non-TLS |
| 109 | Dropbear SSH |
| 110 | Dropbear SSH |
| 443 | Nginx TLS / Stunnel / VLESS WS TLS |
| 8881 | wstunnel WSS (SSH-over-WS) |
| 8882 | wstunnel WS (SSH-over-WS) |
| 10000 | Xray VLESS backend (internal) |

---

## 📡 Connection Examples

### SSH WebSocket (DarkTunnel)

| Field | Value |
|-------|-------|
| Target | `your-domain:443@user:pass` |
| Proxy | `applynow.hdfc.bank.in:443` |
| SNI | `your-domain` |
| Payload | `GET / HTTP/1.1[crlf]Host: your-domain[crlf]Upgrade: websocket[crlf]Connection: <div><span style="color: #0000ff"> ✨❤@ZAINU X BRAND ➡| 03077716993🇵🇰| ✈ •🪶(BOY) 🇸 🅦</span></div> Upgrade[crlf]User-Agent: [ua][crlf][crlf]` |

### VLESS WS TLS

```
vless://<UUID>@your-domain:443?type=ws&security=tls&path=/vless-ws&sni=your-domain#ZAINIX-VLESS
```

### VLESS WS non-TLS

```
vless://<UUID>@your-domain:80?type=ws&security=none&path=/vless-ws#ZAINIX-VLESS
```

---

## 🗑️ Uninstall

```bash
zainix-uninstall
```

Removes all services, configs, certificates, custom banners and created users. After uninstall you can re-run `bash install.sh` for a clean fresh setup.

---

## 📁 Repo Files

| File | Description |
|------|-------------|
| `install.sh` | Master installer (auto-fetches the rest) |
| `menu.sh` | Menu control panel |
| `uninstall.sh` | Full cleaner |
| `README.md` | This file |

---

## 🛠️ Supported OS

- Ubuntu 20.04 / 22.04 / 24.04
- Debian 11 / 12

---

## 📜 License

Personal use only — created for **ZAINI X BRAND**.