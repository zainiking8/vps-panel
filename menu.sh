#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                        ZAINU X BRAND 😎 — LOADER                         ║
# ║          menu.sh  —  GitHub-hosted bootstrap for zainu-vpn.sh            ║
# ║                                                                          ║
# ║   Upload this file to your GitHub repo, then on VPS run:                 ║
# ║     curl -sL https://raw.githubusercontent.com/zainiking8/vps-panel/     ║
# ║          main/menu.sh | sudo bash -s -- --install                        ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -Eeuo pipefail

#────────────────────────────── Rainbow Colors ────────────────────────────────
# ANSI-C quoting so ESC bytes are real (renders in heredocs too)
R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'
B=$'\033[1;34m'; M=$'\033[1;35m'; W=$'\033[1;37m'; K=$'\033[0m'
RD=$'\033[0;31m'; GN=$'\033[0;32m'; YL=$'\033[0;33m'; CY=$'\033[0;36m'; BL=$'\033[0;34m'; MG=$'\033[0;35m'

#────────────────────────────── ⚙️  CONFIG  ⚙️ ───────────────────────────────
# >>> Pre-filled for zainiking8/vps-panel — override via env vars if needed <<<
#   Example:  curl -sL .../menu.sh | sudo GITHUB_USER=other USER=other bash
GITHUB_USER="${GITHUB_USER:-zainiking8}"
REPO_NAME="${REPO_NAME:-vps-panel}"
BRANCH="${BRANCH:-main}"
REMOTE_FILE="${REMOTE_FILE:-zainu-vpn.sh}"   # the big script this loader fetches
INSTALL_DIR="/usr/local/bin"                 # where zainu-vpn.sh lands
LOCAL_NAME="zainu"                           # command name on PATH
#─────────────────────────────────────────────────────────────────────────────

RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/${REMOTE_FILE}"
SELF_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/menu.sh"

#────────────────────────────── Utils ─────────────────────────────────────────
err(){ printf "${RD}[ERR]${K} %s\n" "$*"; }
ok(){  printf "${G}[OK]${K}  %s\n"  "$*"; }
inf(){ printf "${C}[i]${K}  %s\n"   "$*"; }
wr(){  printf "${Y}[!]${K}  %s\n"   "$*"; }
die(){ err "$*"; exit 1; }

#────────────────────────────── Branded banner ─────────────────────────────────
brand_banner(){
printf "\n"
printf "${R}██████${K}${G}╗${K} ${Y}╔${K}${C}════${K}${B}╗${K} ${M}██${K}${W}╗${K} ${R}╔${K}${G}═${K}${Y}╗${K}  ${C}╔${K}${B}╗${K}  ${M}╔${K}${W}══${K}${R}╗${K}\n"
printf "${R}╚${K}${G}══${K}${Y}═${K}${C}╝${K} ${B}║${K} ${M}║${K}  ${W}╚${K}${R}╗${K}${G}║${K} ${Y}║${K} ${C}║${K} ${B}║${K}  ${M}║${K}${W}╔${K}${R}╝${K}\n"
printf "${R}${G} ╔${K}${Y}═${K}${C}╗${K} ${B}║${K} ${M}║${K} ${W}╔${K}${R}╗${K}${G}║${K} ${Y}║${K} ${C}║${K} ${B}║${K}  ${M}║${K}${W}║${K}\n"
printf "${R}${G} ╚${K}${Y}══${K}${C}╝${K} ${B}║${K} ${M}╚${K}${W}╝${K} ${R}╚${K}${G}╝${K} ${Y}╚${K}${C}═${K}${B}╝${K} ${M}╚${K}${W}═${K}${R}╝${K}\n"
printf "${G}  X BRAND 😎${K}\n"
printf "${M}════════════════════════════════════════════════════════════${K}\n"
printf "${C}  PREMIUM VPN SCRIPT  ${K}${Y}—${K} ${B}Loader${K}\n"
printf "${M}════════════════════════════════════════════════════════════${K}\n"
printf "\n"
}

#────────────────────────────── Preflight checks ───────────────────────────────
preflight(){
  [[ $EUID -eq 0 ]] || die "Run as root:  sudo bash menu.sh   (or curl ... | sudo bash)"

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID:-}" in
      ubuntu|debian) ok "OS: ${PRETTY_NAME:-$ID} — supported" ;;
      *) wr "OS: ${PRETTY_NAME:-unknown} — script targets Debian/Ubuntu. Proceeding anyway..." ;;
    esac
  else
    wr "Could not detect OS — proceeding"
  fi

  command -v curl >/dev/null 2>&1 || die "'curl' not found. Install:  apt update && apt install -y curl"

  case "$(uname -m)" in
    x86_64|aarch64|arm64) ok "Arch: $(uname -m) — supported" ;;
    *) wr "Arch $(uname -m) may not be fully supported" ;;
  esac
}

#────────────────────────────── Fetch the big script ───────────────────────────
fetch_script(){
  local dest="/tmp/${REMOTE_FILE}.tmp"
  inf "Downloading ${M}${REMOTE_FILE}${K} from:"
  printf "  ${BL}%s${K}\n" "$RAW_URL"

  local code
  if curl -fL --connect-timeout 15 --max-time 120 --retry 3 \
       -o "$dest" "$RAW_URL" 2>/dev/null; then
    ok "Downloaded"
  else
    code=$?
    die "Download failed (curl exit $code).
  ${Y}Most common cause:${K} '${M}${REMOTE_FILE}${K}' is NOT uploaded to your repo yet.

  Fix:
    1. Open ${C}https://github.com/${GITHUB_USER}/${REPO_NAME}${K}
    2. Upload ${M}${REMOTE_FILE}${K} to branch '${M}${BRANCH}${K}' (same place as menu.sh)
    3. Make sure the repo is ${G}Public${K}
    4. Re-run this command

  Or set custom values inline:
    ${C}curl -sL ${SELF_URL} | sudo REMOTE_FILE=other.sh bash -s -- --install${K}"
  fi

  [[ -s "$dest" ]] || die "Downloaded file is empty"
  head -c2 "$dest" | grep -q '^#!' 2>/dev/null || wr "Warning: file may not be a valid script (no shebang)"

  mkdir -p "$INSTALL_DIR"
  install -m 0755 "$dest" "${INSTALL_DIR}/${REMOTE_FILE}"
  rm -f "$dest"

  ln -sf "${INSTALL_DIR}/${REMOTE_FILE}" "${INSTALL_DIR}/${LOCAL_NAME}"
  ok "Installed → ${M}${INSTALL_DIR}/${REMOTE_FILE}${K}"
  ok "Command  → ${M}${LOCAL_NAME}${K}  (symlink)"
}

#────────────────────────────── Help ──────────────────────────────────────────
print_help(){
  cat <<EOF
${M}ZAINU X BRAND 😎${K} — Loader usage:

  ${G}menu.sh${K}                 Download zainu-vpn.sh, install to ${INSTALL_DIR}/, symlink ${LOCAL_NAME}
  ${G}menu.sh --install${K}       Download + run full install of all protocols
  ${G}menu.sh --menu${K}          Download + open colourful account menu
  ${G}menu.sh --help${K}          This help
  ${G}menu.sh --upgrade${K}       Re-download latest zainu-vpn.sh from GitHub

Curl one-liners:

  ${C}# install everything${K}
  curl -sL ${SELF_URL} | sudo bash -s -- --install

  ${C}# just open the menu${K}
  curl -sL ${SELF_URL} | sudo bash -s -- --menu

  ${C}# upgrade to latest version${K}
  curl -sL ${SELF_URL} | sudo bash -s -- --upgrade

Override defaults without editing the script:
  curl -sL ${SELF_URL} | sudo \\
       GITHUB_USER=other REPO_NAME=other BRANCH=master REMOTE_FILE=myscript.sh \\
       bash -s -- --install

EOF
}

#────────────────────────────── Main ───────────────────────────────────────────
main(){
  brand_banner

  local mode="download"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)  mode="install";  shift ;;
      --menu)     mode="menu";     shift ;;
      --upgrade)  mode="upgrade";  shift ;;
      --help|-h)  print_help; exit 0 ;;
      *) err "Unknown arg: $1"; print_help; exit 2 ;;
    esac
  done

  preflight
  fetch_script

  printf "\n${G}══════════════════════════════════════════════════════${K}\n"

  case "$mode" in
    download)
      # SMART DEFAULT: if zainu-vpn.sh isn't installed yet, install it;
      # otherwise just open the colourful menu.
      if [[ -x /usr/local/bin/zainu-vpn.sh ]] && grep -q 'ZAINU X BRAND' /usr/local/bin/zainu-vpn.sh 2>/dev/null; then
        inf "Already installed — opening menu..."
        printf "${G}══════════════════════════════════════════════════════${K}\n\n"
        exec zainu --menu
      else
        inf "First run — installing ALL protocols..."
        printf "${G}══════════════════════════════════════════════════════${K}\n\n"
        install -m 0755 "${INSTALL_DIR}/${REMOTE_FILE}" /tmp/__zainu_loader_install 2>/dev/null || true
        exec /usr/local/bin/zainu-vpn.sh --install
      fi
      ;;
    install)
      inf "Launching full install..."
      printf "${G}══════════════════════════════════════════════════════${K}\n\n"
      exec /usr/local/bin/zainu-vpn.sh --install
      ;;
    menu)
      inf "Opening menu..."
      printf "${G}══════════════════════════════════════════════════════${K}\n\n"
      exec /usr/local/bin/zainu-vpn.sh --menu
      ;;
    upgrade)
      ok "Upgraded to latest from GitHub"
      printf "Run ${M}menu${K} to open the panel.\n"
      ;;
  esac
}

main "$@"
