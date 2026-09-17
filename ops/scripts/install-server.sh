#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

. /etc/os-release
if [[ ${ID} != "ubuntu" ]]; then
  echo "Ubuntu is required" >&2
  exit 1
fi

ops_directory=$(cd "$(dirname "$0")/.." && pwd)
logrotate_source="$ops_directory/logrotate/legacy-hosting"
if [[ ! -f "$logrotate_source" ]]; then
  echo "Missing bundled logrotate policy: $logrotate_source" >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx mysql-client ca-certificates curl age logrotate
install -d -m 0755 /opt/legacy-hosting/releases /opt/legacy-hosting/incoming
install -d -m 0700 /etc/legacy-hosting /var/backups/legacy-hosting/mysql
install -d -m 0755 /var/www
install -m 0644 "$logrotate_source" /etc/logrotate.d/legacy-hosting
systemctl enable --now nginx

echo "Server directories and operating-system dependencies are ready."
echo "Create /etc/legacy-hosting/api.env, agent.env, and backup.env with mode 0600 before deployment."
