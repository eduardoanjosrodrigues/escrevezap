#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
DIM="\033[2m"

ts()   { echo -e "${DIM}[$(date '+%H:%M:%S')]${RESET}"; }
info() { echo -e "$(ts) ${CYAN}${BOLD}▸ $*${RESET}"; }
ok()   { echo -e "$(ts) ${GREEN}${BOLD}✔ $*${RESET}"; }

SERVER="eduardo@server"
REMOTE_DIR="microsaas/escrevezap"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     🚀 Local Deploy → $SERVER     ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

info "Conectando em $SERVER e rodando deploy..."
echo ""

ssh -t "$SERVER" "cd ~/'$REMOTE_DIR' && bash deploy.sh"

echo ""
ok "Deploy remoto concluído!"
echo ""
