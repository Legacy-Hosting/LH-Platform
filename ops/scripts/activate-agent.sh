#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

base=/opt/legacy-hosting
if [[ ! -L "$base/current" ]]; then
  echo "No active Legacy Hosting release" >&2
  exit 1
fi
"$base/current/ops/scripts/validate-production-env.sh"
ln -sfn /etc/legacy-hosting/agent.env "$base/current/LH-Agent/.env"
pnpm --dir "$base/current/LH-Agent" install --prod --frozen-lockfile
pm2 startOrReload "$base/current/LH-Agent/ecosystem.config.cjs" --update-env
pm2 save
pm2 describe lh-agent >/dev/null
echo "Agent activated. Verify its heartbeat in the panel before disabling legacy signatures."
