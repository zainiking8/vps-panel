#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                        ZAINU X BRAND 😎 — LOADER                         ║
# ║          menu.sh  —  GitHub-hosted bootstrap for zainu-vpn.sh            ║
# ║                                                                          ║
# ║   Upload this file to your GitHub repo, then on VPS run:                 ║
# ║     curl -sL https://raw.githubusercontent.com/USER/REPO/main/menu.sh \  ║
# ║       | sudo bash                                                        ║
# ║   or with args:                                                          ║
# ║     curl -sL https://raw.githubusercontent.com/USER/REPO/main/menu.sh \  ║
# ║       | sudo bash -s -- --install                                        ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -Eeuo pipefail

#────────────────────────────── Rainbow Colors ────────────────────────────────
# ANSI-C quoting so ESC bytes are real (renders in heredocs too)
R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'
B=$'\033[1;34m'; M=$'\033[1;35m'; W=$'\033[1;37m'; K=$'\033[0m'
RD=$'\033[0;31m'; GN=$'\033[0;32m'; YL=$'\033[0;33m'; CY=$'\033[0;36m'; BL=$'\033[0;34m'; MG=$'\033[0;35m'

#────────────────────────────── ⚙️  CONFIG  ⚙️ ───────────────────────────────
# >>> EDIT THESE THREE LINES to match your GitHub repo <<<
GITHUB_USER="YOUR_GITHUB_USERNAME"
REPO_NAME="YOUR_REPO_NAME"
BRANCH="main"
REMOTE_FILE="zainu-vpn.sh"          # the big script this loader fetches
INSTALL_DIR="/usr/local/bin"        # where zainu-vpn.sh lands
LOCAL_NAME="zainu"                  # command name on PATH (zainu-vpn.sh -> zainu)
#─────────────────────────────────────────────────────────────────────────────

# build raw URL
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/${REMOTE_FILE}"

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
  # root?
  [[ $EUID -eq 0 ]] || die "Run as root:  sudo bash menu.sh   (or curl ... | sudo bash)"

  # OS check — Debian/Ubuntu only
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID:-}" in
      ubuntu|debian) ok "OS: ${PRETTY_NAME:-$ID} — supported" ;;
      *) wr "OS: ${PRETTY_NAME:-unknown} — script targets Debian/Ubuntu. Proceeding anyway..." ;;
    esac
  else
    wr "Could not detect OS — proceeding"
  fi

  # internet?
  command -v curl >/dev/null 2>&1 || die "'curl' not found. Install:  apt update && apt install -y curl"

  # arch
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

  # if user hasn't edited the config, bail with a helpful message
  if [[ "$GITHUB_USER" == "YOUR_GITHUB_USERNAME" ]]; then
    err "You have NOT edited the CONFIG block in menu.sh yet!"
    printf "${Y}Open menu.sh and set:${K}\n"
    printf "  ${G}GITHUB_USER${K}=\"your-username\"\n"
    printf "  ${G}REPO_NAME${K}=\"your-repo\"\n"
    printf "  ${G}BRANCH${K}=\"main\"   ${Y}(or master)${K}\n"
    die "Re-upload to GitHub after editing, then run again."
  fi

  # download with retries
  local code
  if curl -fL --connect-timeout 15 --max-time 60 --retry 3 \
       -o "$dest" "$RAW_URL" 2>/dev/null; then
    ok "Downloaded"
  else
    code=$?
    die "Download failed (curl exit $code). Check:
  • URL is correct and repo is public
  • File '${REMOTE_FILE}' exists on branch '${BRANCH}'
  • VPS has internet access"
  fi

  # sanity: non-empty + has shebang
  [[ -s "$dest" ]] || die "Downloaded file is empty"
  head -c2 "$dest" | grep -q '^#!' 2>/dev/null || wr "Warning: file may not be a valid script (no shebang)"

  # install to INSTALL_DIR
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "$dest" "${INSTALL_DIR}/${REMOTE_FILE}"
  rm -f "$dest"

  # convenience symlink:  zainu  ->  zainu-vpn.sh
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

Curl one-liners (after uploading to GitHub):

  ${C}# install everything${K}
  curl -sL https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/menu.sh | sudo bash -s -- --install

  ${C}# just open the menu${K}
  curl -sL https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/menu.sh | sudo bash -s -- --menu

EOF
}

#────────────────────────────── Main ───────────────────────────────────────────
main(){
  brand_banner

  # parse args
  local mode="download"   # default: just download + install
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
      ok "Done. Now run:"
      printf "  ${M}%s --menu${K}      # open account panel\n" "$LOCAL_NAME"
      printf "  ${M}%s --install${K}   # (re)install all protocols\n" "$LOCAL_NAME"
      ;;
    install)
      inf "Launching full install..."
      printf "${G}══════════════════════════════════════════════════════${K}\n\n"
      exec "${INSTALL_DIR}/${REMOTE_FILE}" --install
      ;;
    menu)
      inf "Opening menu..."
      printf "${G}══════════════════════════════════════════════════════${K}\n\n"
      exec "${INSTALL_DIR}/${REMOTE_FILE}" --menu
      ;;
    upgrade)
      ok "Upgraded to latest from GitHub"
      printf "Run ${M}%s --menu${K} to continue.\n" "$LOCAL_NAME"
      ;;
  esac
}

main "$@"
