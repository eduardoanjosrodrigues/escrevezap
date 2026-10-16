#!/usr/bin/env bash
# Reinicia a máquina se a internet ficar fora por muito tempo.
#
# - checa a cada CHECK_INTERVAL segundos (ping em 1.1.1.1/8.8.8.8 + HTTPS)
# - aos RESET_LINK_AFTER segundos fora: tenta derrubar/subir a interface
# - aos REBOOT_AFTER segundos fora: reinicia
# - se o último reboot do watchdog foi há menos de BACKOFF_WINDOW, espera
#   BACKOFF_REBOOT_AFTER (evita reboot a cada 30min quando o problema é a operadora)
#
# Logs: journalctl -u net-watchdog

set -u

IFACE="${IFACE:-enp2s0}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
RESET_LINK_AFTER="${RESET_LINK_AFTER:-600}"        # 10 min
REBOOT_AFTER="${REBOOT_AFTER:-1800}"               # 30 min
BACKOFF_WINDOW="${BACKOFF_WINDOW:-10800}"          # 3 h
BACKOFF_REBOOT_AFTER="${BACKOFF_REBOOT_AFTER:-7200}" # 2 h
STATE_DIR=/var/lib/net-watchdog

mkdir -p "$STATE_DIR"

log() { echo "$*"; }

online() {
  ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 && return 0
  ping -c1 -W3 8.8.8.8 >/dev/null 2>&1 && return 0
  curl -s -o /dev/null -m 8 https://www.google.com/generate_204 && return 0
  return 1
}

gateway() { ip route show default | awk '/default/ {print $3; exit}'; }

diagnose() {
  local gw; gw="$(gateway)"
  log "diag: default gateway=${gw:-none}"
  if [ -n "$gw" ] && ping -c1 -W3 "$gw" >/dev/null 2>&1; then
    log "diag: gateway REACHABLE (provável problema na operadora/roteador)"
  else
    log "diag: gateway UNREACHABLE (provável problema na placa de rede/servidor)"
  fi
  ip -br link show "$IFACE" | sed 's/^/diag: /'
  ip -s link show "$IFACE" | sed 's/^/diag: /'
  dmesg 2>/dev/null | grep -iE "r8169|$IFACE|NETDEV" | tail -10 | sed 's/^/diag: /'
}

reboot_threshold() {
  local last now
  last="$(cat "$STATE_DIR/last_reboot" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  if [ $((now - last)) -lt "$BACKOFF_WINDOW" ]; then
    echo "$BACKOFF_REBOOT_AFTER"
  else
    echo "$REBOOT_AFTER"
  fi
}

down_since=""
link_reset_done=0

log "started (iface=$IFACE, reboot after ${REBOOT_AFTER}s)"

while true; do
  if online; then
    if [ -n "$down_since" ]; then
      log "internet back after $(( $(date +%s) - down_since ))s"
    fi
    down_since=""
    link_reset_done=0
  else
    now="$(date +%s)"
    if [ -z "$down_since" ]; then
      down_since="$now"
      log "internet DOWN"
      diagnose
    fi
    elapsed=$((now - down_since))
    threshold="$(reboot_threshold)"
    log "still down for ${elapsed}s (reboot at ${threshold}s)"

    if [ "$link_reset_done" -eq 0 ] && [ "$elapsed" -ge "$RESET_LINK_AFTER" ]; then
      log "resetting link $IFACE"
      ip link set "$IFACE" down
      sleep 3
      ip link set "$IFACE" up
      networkctl reconfigure "$IFACE" 2>/dev/null || true
      link_reset_done=1
    fi

    if [ "$elapsed" -ge "$threshold" ]; then
      log "REBOOTING after ${elapsed}s without internet"
      diagnose
      date +%s > "$STATE_DIR/last_reboot"
      sync
      systemctl reboot
      sleep 300
    fi
  fi
  sleep "$CHECK_INTERVAL"
done
