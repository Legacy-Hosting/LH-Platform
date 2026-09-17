# Backup and recovery

DigitalOcean Managed MySQL automated backups and point-in-time recovery are the primary database recovery layer. A daily encrypted logical export provides an independent recovery path.

`configure-production.sh` generates the age identity and writes the protected backup environment without exposing passwords in shell history.

## Logical backup

Configure `/etc/legacy-hosting/backup.env` with mode `0600`. Use a read-only backup user where possible and set an `age` recipient. Run `ops/scripts/backup-mysql.sh` daily from systemd or cron. The script writes only encrypted `.sql.gz.age` files and SHA-256 checksums under `/var/backups/legacy-hosting/mysql`.

Copy encrypted backups to a separate account or region. Local retention defaults to 14 days. Provider retention and off-site retention must be documented before launch.

## Restore drill

Run `ops/scripts/restore-drill.sh BACKUP` against a disposable database name beginning with `lh_restore_drill_`. The drill verifies decryption, schema import, and the migration ledger, then removes only that explicitly named drill database.

Perform a restore drill before the first launch and at least quarterly. Record duration, backup timestamp, migration count, and any errors.

## Recovery objectives

- Target RPO: DigitalOcean PITR window or 24 hours for independent logical exports.
- Target RTO: 60 minutes after database credentials and a clean application release are available.
