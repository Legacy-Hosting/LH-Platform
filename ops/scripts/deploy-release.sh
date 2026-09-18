#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 || $# -ne 3 ]]; then
  echo "Usage as root: $0 ARCHIVE CHECKSUM VERSION" >&2
  exit 1
fi
archive=$(readlink -f "$1")
checksum=$(readlink -f "$2")
version=$3
if [[ ! -f "$archive" || ! -f "$checksum" || ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Invalid release archive, checksum, or version" >&2
  exit 1
fi
expected=$(awk 'NR==1 {print $1}' "$checksum")
actual=$(sha256sum "$archive" | awk '{print $1}')
if [[ ! $expected =~ ^[a-f0-9]{64}$ || $expected != "$actual" ]]; then
  echo "Release checksum verification failed" >&2
  exit 1
fi

base=/opt/legacy-hosting
release="$base/releases/$version"
if [[ -e "$release" ]]; then
  echo "Release already exists: $release" >&2
  exit 1
fi
staging=$(mktemp -d "$base/releases/.staging-${version}.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
tar -xzf "$archive" --no-same-owner --strip-components=1 -C "$staging"
for path in LH-API/package.json LH-API/dist/server.js LH-Agent/dist/index.js LH-Panel/dist/index.html artifacts/lh-agent-runtime.tar.gz artifacts/lh-agent-runtime.tar.gz.sha256 ops/scripts/install-node-agent.sh; do
  if [[ ! -e "$staging/$path" ]]; then
    echo "Release is missing $path" >&2
    exit 1
  fi
done

agent_enabled=false
if [[ -f /etc/legacy-hosting/agent.env ]]; then
  agent_enabled=true
  "$staging/ops/scripts/validate-production-env.sh"
else
  "$staging/ops/scripts/validate-production-env.sh" /etc/legacy-hosting/api.env /etc/legacy-hosting/agent.env api-only
  echo "API/panel deployment will continue without the pending agent enrollment."
fi
for certificate in api.legacyhosting.xyz panel.legacyhosting.xyz; do
  if [[ ! -r "/etc/letsencrypt/live/$certificate/fullchain.pem" || ! -r "/etc/letsencrypt/live/$certificate/privkey.pem" ]]; then
    echo "Missing TLS certificate for $certificate" >&2
    exit 1
  fi
done
ln -s /etc/legacy-hosting/api.env "$staging/LH-API/.env"
if [[ $agent_enabled == true ]]; then
  ln -s /etc/legacy-hosting/agent.env "$staging/LH-Agent/.env"
fi
pnpm --dir "$staging/LH-API" install --prod --frozen-lockfile
pnpm --dir "$staging/LH-Agent" install --prod --frozen-lockfile
BACKUP_ENV_FILE=/etc/legacy-hosting/backup.env "$staging/ops/scripts/backup-mysql.sh"
(cd "$staging/LH-API" && node dist/core/database/migrate.js)

chown -R root:root "$staging"
chmod 0755 "$staging"
mv "$staging" "$release"
trap - EXIT
previous=
if [[ -L "$base/current" ]]; then
  current_target=$(readlink -f "$base/current" 2>/dev/null || true)
  if [[ -n $current_target && $current_target == "$base/releases/"* && -d $current_target ]]; then
    previous=$current_target
    ln -sfn "$previous" "$base/previous"
  fi
elif [[ -e "$base/current" ]]; then
  echo "$base/current must be a release symlink" >&2
  exit 1
fi
ln -sfn "$release" "$base/current"
ln -sfn "$base/current/LH-Panel/dist" /var/www/legacy-hosting-panel

rollback_on_error() {
  if [[ -n $previous && -d $previous ]]; then
    ln -sfn "$previous" "$base/current"
    ln -sfn "$base/current/LH-Panel/dist" /var/www/legacy-hosting-panel
    for process_name in lh-api lh-certificate-worker lh-monitoring-worker; do
      pm2 delete "$process_name" >/dev/null 2>&1 || true
    done
    pm2 start "$previous/LH-API/ecosystem.config.cjs" --update-env || true
    if [[ -f /etc/legacy-hosting/agent.env ]]; then
      pm2 delete lh-agent >/dev/null 2>&1 || true
      pm2 start "$previous/LH-Agent/ecosystem.config.cjs" --update-env || true
    fi
  fi
}
trap rollback_on_error ERR
for process_name in lh-api lh-certificate-worker lh-monitoring-worker; do
  pm2 delete "$process_name" >/dev/null 2>&1 || true
done
pm2 start "$release/LH-API/ecosystem.config.cjs" --update-env
if [[ $agent_enabled == true ]]; then
  pm2 delete lh-agent >/dev/null 2>&1 || true
  pm2 start "$release/LH-Agent/ecosystem.config.cjs" --update-env
fi
pm2 save
curl --fail --silent --show-error --retry 10 --retry-delay 2 --retry-connrefused \
  http://127.0.0.1:8080/health | grep -q '"status":"ok"'

install -m 0644 "$release/ops/nginx/api.legacyhosting.xyz.conf" /etc/nginx/sites-available/api.legacyhosting.xyz.conf
install -m 0644 "$release/ops/nginx/panel.legacyhosting.xyz.conf" /etc/nginx/sites-available/panel.legacyhosting.xyz.conf
ln -sfn /etc/nginx/sites-available/api.legacyhosting.xyz.conf /etc/nginx/sites-enabled/api.legacyhosting.xyz.conf
ln -sfn /etc/nginx/sites-available/panel.legacyhosting.xyz.conf /etc/nginx/sites-enabled/panel.legacyhosting.xyz.conf
nginx -t
systemctl reload nginx

install -m 0644 "$release/ops/systemd/lh-backup.service" /etc/systemd/system/lh-backup.service
install -m 0644 "$release/ops/systemd/lh-backup.timer" /etc/systemd/system/lh-backup.timer
systemctl daemon-reload
systemctl enable --now lh-backup.timer
trap - ERR

printf '%s\n' "$version" > "$base/current-release"
echo "Release $version deployed and local API health passed."
