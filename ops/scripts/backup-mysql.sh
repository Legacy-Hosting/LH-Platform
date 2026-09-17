#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

environment_file=${BACKUP_ENV_FILE:-/etc/legacy-hosting/backup.env}
if [[ ! -f "$environment_file" ]]; then
  echo "Missing $environment_file" >&2
  exit 1
fi
. "$environment_file"

required=(DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_SSL_CA BACKUP_AGE_RECIPIENT)
for name in "${required[@]}"; do
  if [[ -z ${!name:-} ]]; then
    echo "Missing backup setting: $name" >&2
    exit 1
  fi
done

backup_directory=/var/backups/legacy-hosting/mysql
install -d -m 0700 "$backup_directory"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
temporary=$(mktemp "$backup_directory/.legacyhosting-${timestamp}.XXXXXX.sql.gz")
encrypted="$backup_directory/legacyhosting-${timestamp}.sql.gz.age"
trap 'rm -f -- "$temporary"' EXIT

MYSQL_PWD=$DB_PASSWORD mysqldump \
  --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca="$DB_SSL_CA" \
  --single-transaction --quick --routines --triggers --events \
  --set-gtid-purged=OFF --default-character-set=utf8mb4 \
  "$DB_NAME" | gzip -9 > "$temporary"

gzip -t "$temporary"
age --recipient "$BACKUP_AGE_RECIPIENT" --output "$encrypted" "$temporary"
sha256sum "$encrypted" > "$encrypted.sha256"
chmod 0600 "$encrypted" "$encrypted.sha256"
rm -f -- "$temporary"
trap - EXIT

retention_days=${BACKUP_RETENTION_DAYS:-14}
if ! [[ $retention_days =~ ^[0-9]+$ ]] || (( retention_days < 1 || retention_days > 365 )); then
  echo "BACKUP_RETENTION_DAYS must be between 1 and 365" >&2
  exit 1
fi
find "$backup_directory" -maxdepth 1 -type f \
  \( -name 'legacyhosting-*.sql.gz.age' -o -name 'legacyhosting-*.sql.gz.age.sha256' \) \
  -mtime "+$retention_days" -delete

echo "Encrypted backup created: $encrypted"
