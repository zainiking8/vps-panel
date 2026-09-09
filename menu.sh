#!/usr/bin/env bash
# ZAINU X BRAND 😎 — VPN Panel Loader
# Small bootstrap: downloads zainu.sh from GitHub and runs the requested action.
# The MAIN script is zainu.sh — all install / menu / check / activate logic lives there.

set -Eeuo pipefail

GITHUB_USER="zainiking8"
REPO_NAME="vps-panel"
BRANCH="main"
REMOTE_FILE="zainu.sh"
LOCAL="/usr/local/bin/zainu-sh"

R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'; B=$'\033[1;34m'; M=$'\033[1;35m'; K=$'\033[0m'

# Pass-through args (install / menu / check / activate / status / uninstall / etc.)
ARGS=("$@")
[[ ${#ARGS[@]} -eq 0 ]] && ARGS=(install)

URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/${REMOTE_FILE}"

# Always try to fetch the latest copy
if command -v curl >/dev/null 2>&1; then
  if curl -fsSL -o "$LOCAL" "$URL" 2>/dev/null; then
    chmod +x "$LOCAL" 2>/dev/null || true
    [[ -s "$LOCAL" ]] && exec bash "$LOCAL" "${ARGS[@]}"
  fi
fi

# Fallback to cached local copy
if [[ -s "$LOCAL" ]]; then
  echo -e "${Y}⚠️  Could not download fresh zainu.sh — using cached copy${K}" >&2
  exec bash "$LOCAL" "${ARGS[@]}"
fi

cat >&2 <<EOF
${R}╔════════════════════════════════════════════════════════════╗
║  ZAINU X BRAND 😎 — Loader failed                          ║
╚════════════════════════════════════════════════════════════╝${K}
${R}Could not download:${C} $URL${K}

${Y}Fix:${K}
  1. Make sure ${C}zainu.sh${K} is in ${C}https://github.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}${K}
  2. Repo must be ${G}Public${K}
  3. Run again manually:
     ${G}curl -o /usr/local/bin/zainu-sh $URL && chmod +x /usr/local/bin/zainu-sh && bash /usr/local/bin/zainu-sh install${K}
EOF
exit 1