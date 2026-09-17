#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /var/backups/legacy-hosting/mysql/BACKUP.sql.gz.age" >&2
  exit 1
fi
backup=$(readlink -f "$1")
if [[ ! -f "$backup" || $backup != /var/backups/legacy-hosting/mysql/*.sql.gz.age ]]; then
  echo "Backup must be an encrypted file in /var/backups/legacy-hosting/mysql" >&2
  exit 1
fi
sha256sum -c "$backup.sha256"

. /etc/legacy-hosting/backup.env
required=(DB_HOST DB_PORT DB_ADMIN_USER DB_ADMIN_PASSWORD DB_SSL_CA BACKUP_AGE_IDENTITY)
for name in "${required[@]}"; do
  if [[ -z ${!name:-} ]]; then
    echo "Missing restore setting: $name" >&2
    exit 1
  fi
done

database_name="lh_restore_drill_$(date -u +%Y%m%d_%H%M%S)"
if [[ ! $database_name =~ ^lh_restore_drill_[0-9_]+$ ]]; then
  echo "Unsafe restore database name" >&2
  exit 1
fi
mysql_command=(mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_ADMIN_USER" --ssl-mode=VERIFY_IDENTITY --ssl-ca="$DB_SSL_CA")
cleanup() {
  MYSQL_PWD=$DB_ADMIN_PASSWORD "${mysql_command[@]}" -e "DROP DATABASE IF EXISTS \`$database_name\`;" >/dev/null
}
trap cleanup EXIT

MYSQL_PWD=$DB_ADMIN_PASSWORD "${mysql_command[@]}" -e "CREATE DATABASE \`$database_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
age --decrypt --identity "$BACKUP_AGE_IDENTITY" "$backup" | gzip -dc | \
  MYSQL_PWD=$DB_ADMIN_PASSWORD "${mysql_command[@]}" "$database_name"
migration_count=$(MYSQL_PWD=$DB_ADMIN_PASSWORD "${mysql_command[@]}" --batch --skip-column-names "$database_name" -e "SELECT COUNT(*) FROM schema_migrations;")
if ! [[ $migration_count =~ ^[0-9]+$ ]] || (( migration_count < 1 )); then
  echo "Restore drill failed: migration ledger is missing" >&2
  exit 1
fi
echo "Restore drill passed with $migration_count migrations. The disposable database will now be removed."
