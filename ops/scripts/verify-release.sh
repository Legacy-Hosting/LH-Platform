#!/usr/bin/env bash
set -Eeuo pipefail

base=/opt/legacy-hosting
test -L "$base/current"
test -f "$base/current-release"
test -f /var/www/legacy-hosting-panel/index.html
curl --fail --silent --show-error http://127.0.0.1:8080/health | grep -q '"database":"connected"'
pm2 describe lh-api >/dev/null
pm2 describe lh-certificate-worker >/dev/null
pm2 describe lh-monitoring-worker >/dev/null
if [[ -f /etc/legacy-hosting/agent.env ]]; then
  pm2 describe lh-agent >/dev/null
else
  echo "Agent enrollment is pending; API/panel stage only."
fi
nginx -t
echo "Release verification passed for $(cat "$base/current-release")."
