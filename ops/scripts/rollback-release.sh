#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 || $# -ne 1 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Usage as root: $0 VERSION" >&2
  exit 1
fi
base=/opt/legacy-hosting
target="$base/releases/$1"
if [[ ! -d "$target/LH-API" || ! -d "$target/LH-Panel/dist" ]]; then
  echo "Release does not exist: $target" >&2
  exit 1
fi
current=$(readlink -f "$base/current" 2>/dev/null || true)
if [[ -n $current && $current == "$base/releases/"* ]]; then
  ln -sfn "$current" "$base/previous"
fi
ln -sfn "$target" "$base/current"
ln -sfn "$base/current/LH-Panel/dist" /var/www/legacy-hosting-panel
pm2 delete lh-api lh-certificate-worker lh-monitoring-worker >/dev/null 2>&1 || true
pm2 start "$base/current/LH-API/ecosystem.config.cjs" --update-env
if [[ -f /etc/legacy-hosting/agent.env ]]; then
  ln -sfn /etc/legacy-hosting/agent.env "$base/current/LH-Agent/.env"
  pm2 delete lh-agent >/dev/null 2>&1 || true
  pm2 start "$base/current/LH-Agent/ecosystem.config.cjs" --update-env
fi
pm2 save
curl --fail --silent --show-error --retry 10 --retry-delay 2 http://127.0.0.1:8080/health | grep -q '"status":"ok"'
printf '%s\n' "$1" > "$base/current-release"
echo "Rolled back application code to $1. Database migrations were intentionally left in place."
