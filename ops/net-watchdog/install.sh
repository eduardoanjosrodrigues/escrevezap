#!/usr/bin/env bash
# Rodar no servidor: sudo bash install.sh
set -euo pipefail
cd "$(dirname "$0")"
install -m 755 net-watchdog.sh /usr/local/bin/net-watchdog.sh
install -m 644 net-watchdog.service /etc/systemd/system/net-watchdog.service
systemctl daemon-reload
systemctl enable --now net-watchdog
systemctl status net-watchdog --no-pager
