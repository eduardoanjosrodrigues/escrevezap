#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
DIM="\033[2m"

ts()   { echo -e "${DIM}[$(date '+%H:%M:%S')]${RESET}"; }
info() { echo -e "$(ts) ${CYAN}${BOLD}▸ $*${RESET}"; }
ok()   { echo -e "$(ts) ${GREEN}${BOLD}✔ $*${RESET}"; }
warn() { echo -e "$(ts) ${YELLOW}${BOLD}⚠ $*${RESET}"; }
fail() { echo -e "$(ts) ${RED}${BOLD}✘ $*${RESET}"; exit 1; }

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        🚀 Deploy: EscreveZap        ║${RESET}"
echo -e "${BOLD}║   $(date '+%Y-%m-%d %H:%M:%S')              ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Pull latest code ──────────────────────────────────────────────────
info "Pulling latest code from origin..."
git pull || fail "git pull failed"
ok "Code up to date — $(git log -1 --format='%h %s')"
echo ""

# ── Step 2: Build & start containers ─────────────────────────────────────────
info "Building images and starting containers..."
docker compose -f docker-compose-production.yml up --build -d || fail "docker compose failed"
echo ""

# ── Step 3: Health check ──────────────────────────────────────────────────────
info "Waiting for web container to become healthy..."
for i in $(seq 1 12); do
  STATUS=$(docker compose -f docker-compose-production.yml ps --format json web 2>/dev/null \
    | grep -o '"Health":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
  STATE=$(docker compose -f docker-compose-production.yml ps --format json web 2>/dev/null \
    | grep -o '"State":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
  if [[ "$STATE" == "running" ]]; then
    ok "Container web is running"
    break
  fi
  echo -e "  ${DIM}  attempt $i/12 — state: ${STATE:-unknown}...${RESET}"
  sleep 5
  [[ $i -eq 12 ]] && warn "Container did not report healthy after 60s — check logs"
done
echo ""

# ── Step 4: Show running services ────────────────────────────────────────────
info "Running services:"
docker compose -f docker-compose-production.yml ps --format "table {{.Name}}\t{{.Status}}" \
  | tail -n +2 \
  | while IFS= read -r line; do
      if echo "$line" | grep -q "Up\|running"; then
        echo -e "  ${GREEN}●${RESET} $line"
      else
        echo -e "  ${RED}●${RESET} $line"
      fi
    done
echo ""

ok "Deploy complete 🎉"
echo ""
