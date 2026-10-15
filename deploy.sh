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

DC="docker compose -f docker-compose-production.yml"

# ── Step 2: Build images (site keeps running on the old container) ──────────
info "Building images..."
$DC build || fail "docker compose build failed"
ok "Images built"
echo ""

# ── Step 3: Rolling swap of web (no downtime) ─────────────────────────────────
# cloudflared reaches the app as http://web on the "edge" network. The new
# container is created outside "edge", boots (db:prepare + Puma) while the old
# one keeps serving, and only joins "edge" once /up answers. Then the old one
# is stopped gracefully. Recreating in place left the site down while Rails
# booted, and Thruster answers 502 for a few seconds before Puma is ready.
OLD_WEB=$($DC ps -q web)

info "Creating new web container (outside the tunnel network)..."
$DC up --no-start --no-deps --no-recreate --scale web=$(( $(echo "$OLD_WEB" | grep -c .) + 1 )) web \
  || fail "could not create new web container"
NEW_WEB=$($DC ps -a -q web | grep -vxF "${OLD_WEB:-none}" | head -1)
[[ -n "$NEW_WEB" ]] || fail "new web container not found"
EDGE_NET="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$NEW_WEB")_edge"
docker network disconnect "$EDGE_NET" "$NEW_WEB" >/dev/null 2>&1 || true
docker start "$NEW_WEB" >/dev/null || fail "could not start new web container"

info "Waiting for new web container to become healthy..."
HEALTH=""
for i in $(seq 1 60); do
  HEALTH=$(docker inspect --format '{{.State.Health.Status}}' "$NEW_WEB" 2>/dev/null || echo "missing")
  [[ "$HEALTH" == "healthy" ]] && break
  if [[ "$HEALTH" == "unhealthy" || "$HEALTH" == "missing" ]]; then break; fi
  echo -e "  ${DIM}  attempt $i/60 — health: ${HEALTH}...${RESET}"
  sleep 3
done

if [[ "$HEALTH" != "healthy" ]]; then
  warn "New web container is ${HEALTH:-not healthy} — rolling back, old one stays live"
  docker logs --tail 50 "$NEW_WEB" 2>&1 || true
  docker rm -f "$NEW_WEB" >/dev/null 2>&1 || true
  fail "Deploy aborted (site still on previous version)"
fi
ok "New web container is healthy"

info "Putting new web container behind the tunnel..."
docker network connect --alias web "$EDGE_NET" "$NEW_WEB" || fail "could not attach new web to $EDGE_NET"

if [[ -n "$OLD_WEB" ]]; then
  info "Stopping old web container..."
  for id in $OLD_WEB; do
    # SIGTERM: Thruster/Puma stop accepting and finish in-flight requests;
    # cloudflared falls back to the new container on connection refused.
    docker stop --time 30 "$id" >/dev/null && docker rm "$id" >/dev/null
  done
  ok "Old web container removed"
fi
echo ""

# ── Step 4: Update the other services (worker, etc.) ──────────────────────────
info "Updating remaining services..."
OTHERS=$($DC config --services | grep -vx web)
$DC up -d --no-deps $OTHERS || fail "docker compose up failed"
echo ""

# ── Step 5: Show running services ────────────────────────────────────────────
info "Running services:"
$DC ps --format "table {{.Name}}\t{{.Status}}" \
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
