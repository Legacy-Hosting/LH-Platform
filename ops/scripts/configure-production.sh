#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [[ ${EUID} -ne 0 || ! -t 0 ]]; then
  echo "Run interactively as root" >&2
  exit 1
fi

api_target=/etc/legacy-hosting/api.env
backup_target=/etc/legacy-hosting/backup.env
bootstrap_target=/etc/legacy-hosting/bootstrap-token
age_identity=/etc/legacy-hosting/backup-age-key.txt
for target in "$api_target" "$backup_target" "$bootstrap_target" "$age_identity"; do
  if [[ -e "$target" ]]; then
    echo "$target already exists; move the existing protected file before reconfiguring" >&2
    exit 1
  fi
done

read_required() {
  local prompt=$1
  local variable_name=$2
  local secret=${3:-false}
  local value
  if [[ $secret == true ]]; then
    read -r -s -p "$prompt: " value
    printf '\n'
  else
    read -r -p "$prompt: " value
  fi
  if [[ -z $value || $value == *\'* ]]; then
    echo "Values must be non-empty and cannot contain a single quote" >&2
    exit 1
  fi
  printf -v "$variable_name" '%s' "$value"
}

write_value() {
  printf "%s='%s'\n" "$1" "$2"
}

read_required "DigitalOcean Managed MySQL DATABASE_URL" database_url true
read_required "Cloudflare OAuth client ID" cloudflare_client_id
read_required "Cloudflare OAuth client secret" cloudflare_client_secret true
read_required "GitHub App ID" github_app_id
read_required "GitHub App slug" github_app_slug
read_required "GitHub OAuth client ID" github_client_id
read_required "GitHub OAuth client secret" github_client_secret true
read_required "Path to the GitHub App private PEM key" github_private_key_path
if [[ ! -r $github_private_key_path ]]; then
  echo "Cannot read GitHub App private key: $github_private_key_path" >&2
  exit 1
fi
github_private_key_base64=$(base64 -w0 "$github_private_key_path")

read_required "Managed MySQL host for backups" db_host
read_required "Managed MySQL port" db_port
read_required "Managed MySQL database name" db_name
read_required "Managed MySQL backup user" db_user
read_required "Managed MySQL backup password" db_password true
read_required "Managed MySQL admin user for restore drills" db_admin_user
read_required "Managed MySQL admin password" db_admin_password true
read_required "Path to the DigitalOcean MySQL CA certificate" db_ssl_ca
if [[ ! -r $db_ssl_ca ]]; then
  echo "Cannot read database CA certificate: $db_ssl_ca" >&2
  exit 1
fi

credential_key=$(openssl rand -base64 32 | tr -d '\n')
csrf_secret=$(openssl rand -hex 32)
github_webhook_secret=$(openssl rand -hex 32)
bootstrap_token=$(openssl rand -hex 32)
install -d -m 0700 /etc/legacy-hosting
api_temporary=$(mktemp /etc/legacy-hosting/.api.env.XXXXXX)
backup_temporary=$(mktemp /etc/legacy-hosting/.backup.env.XXXXXX)
age_temporary=$(mktemp /etc/legacy-hosting/.backup-age-key.XXXXXX)
rm -f -- "$age_temporary"
trap 'rm -f -- "$api_temporary" "$backup_temporary" "$age_temporary"' EXIT
age-keygen -o "$age_temporary" >/dev/null 2>&1
chmod 0600 "$age_temporary"
age_recipient=$(age-keygen -y "$age_temporary")
{
  write_value NODE_ENV production
  write_value HOST 127.0.0.1
  write_value PORT 8080
  write_value TRUST_PROXY true
  write_value PANEL_ORIGIN https://panel.legacyhosting.xyz
  write_value DATABASE_URL "$database_url"
  write_value SESSION_COOKIE_DOMAIN .legacyhosting.xyz
  write_value SESSION_TTL_DAYS 30
  write_value WEBAUTHN_RP_NAME "Legacy Hosting"
  write_value WEBAUTHN_RP_ID legacyhosting.xyz
  write_value WEBAUTHN_ORIGIN https://panel.legacyhosting.xyz
  write_value INITIAL_ADMIN_TOKEN "$bootstrap_token"
  write_value CREDENTIAL_ENCRYPTION_KEY "$credential_key"
  write_value CSRF_SECRET "$csrf_secret"
  write_value BODY_LIMIT_BYTES 1048576
  write_value RATE_LIMIT_MAX 300
  write_value RATE_LIMIT_WINDOW_MS 60000
  write_value ALLOW_LEGACY_AGENT_SIGNATURES true
  write_value CLOUDFLARE_OAUTH_CLIENT_ID "$cloudflare_client_id"
  write_value CLOUDFLARE_OAUTH_CLIENT_SECRET "$cloudflare_client_secret"
  write_value CLOUDFLARE_OAUTH_REDIRECT_URI https://api.legacyhosting.xyz/api/v1/integrations/cloudflare/callback
  write_value CLOUDFLARE_OAUTH_SCOPES "dns.read dns.write zone.read user-details.read offline_access"
  write_value ACME_EMAIL angel@legacyhosting.xyz
  write_value CERTIFICATE_RENEWAL_DAYS 30
  write_value GITHUB_APP_ID "$github_app_id"
  write_value GITHUB_APP_SLUG "$github_app_slug"
  write_value GITHUB_CLIENT_ID "$github_client_id"
  write_value GITHUB_CLIENT_SECRET "$github_client_secret"
  write_value GITHUB_APP_PRIVATE_KEY_BASE64 "$github_private_key_base64"
  write_value GITHUB_WEBHOOK_SECRET "$github_webhook_secret"
  write_value GITHUB_API_VERSION 2026-03-10
  write_value MONITORING_INTERVAL_MS 30000
} > "$api_temporary"
{
  write_value DB_HOST "$db_host"
  write_value DB_PORT "$db_port"
  write_value DB_NAME "$db_name"
  write_value DB_USER "$db_user"
  write_value DB_PASSWORD "$db_password"
  write_value DB_SSL_CA "$db_ssl_ca"
  write_value DB_ADMIN_USER "$db_admin_user"
  write_value DB_ADMIN_PASSWORD "$db_admin_password"
  write_value BACKUP_AGE_RECIPIENT "$age_recipient"
  write_value BACKUP_AGE_IDENTITY "$age_identity"
  write_value BACKUP_RETENTION_DAYS 14
} > "$backup_temporary"

chmod 0600 "$api_temporary" "$backup_temporary"
mv "$age_temporary" "$age_identity"
mv "$api_temporary" "$api_target"
mv "$backup_temporary" "$backup_target"
printf '%s\n' "$bootstrap_token" > "$bootstrap_target"
chmod 0600 "$bootstrap_target"
trap - EXIT

echo "Created protected API, backup, age identity, and one-time bootstrap-token files."
echo "Use $bootstrap_target during first Windows Hello registration, then remove that file and INITIAL_ADMIN_TOKEN from api.env."
