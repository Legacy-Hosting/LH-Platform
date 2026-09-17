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
tar -xzf "$archive" --strip-components=1 -C "$staging"
for path in LH-API/package.json LH-API/dist/server.js LH-Agent/dist/index.js LH-Panel/dist/index.html; do
  if [[ ! -e "$staging/$path" ]]; then
    echo "Release is missing $path" >&2
    exit 1
  fi
done

"$staging/ops/scripts/validate-production-env.sh"
ln -s /etc/legacy-hosting/api.env "$staging/LH-API/.env"
ln -s /etc/legacy-hosting/agent.env "$staging/LH-Agent/.env"
pnpm --dir "$staging/LH-API" install --prod --frozen-lockfile
pnpm --dir "$staging/LH-Agent" install --prod --frozen-lockfile
BACKUP_ENV_FILE=/etc/legacy-hosting/backup.env "$staging/ops/scripts/backup-mysql.sh"
(cd "$staging/LH-API" && node dist/core/database/migrate.js)

mv "$staging" "$release"
trap - EXIT
previous=$(readlink -f "$base/current" 2>/dev/null || true)
if [[ -n $previous && $previous == "$base/releases/"* ]]; then
  ln -sfn "$previous" "$base/previous"
fi
ln -sfn "$release" "$base/current"
ln -sfn "$base/current/LH-Panel/dist" /var/www/legacy-hosting-panel

rollback_on_error() {
  if [[ -n $previous && -d $previous ]]; then
    ln -sfn "$previous" "$base/current"
    ln -sfn "$base/current/LH-Panel/dist" /var/www/legacy-hosting-panel
    pm2 startOrReload "$base/current/LH-API/ecosystem.config.cjs" --update-env || true
    pm2 startOrReload "$base/current/LH-Agent/ecosystem.config.cjs" --update-env || true
  fi
}
trap rollback_on_error ERR
pm2 startOrReload "$base/current/LH-API/ecosystem.config.cjs" --update-env
pm2 startOrReload "$base/current/LH-Agent/ecosystem.config.cjs" --update-env
pm2 save
curl --fail --silent --show-error --retry 10 --retry-delay 2 http://127.0.0.1:8080/health | grep -q '"status":"ok"'
trap - ERR

printf '%s\n' "$version" > "$base/current-release"
echo "Release $version deployed and local API health passed."
