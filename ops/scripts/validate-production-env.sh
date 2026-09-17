#!/usr/bin/env bash
set -Eeuo pipefail

api_env=${1:-/etc/legacy-hosting/api.env}
agent_env=${2:-/etc/legacy-hosting/agent.env}
validation_mode=${3:-full}

if [[ $validation_mode != "full" && $validation_mode != "api-only" ]]; then
  echo "Validation mode must be full or api-only" >&2
  exit 1
fi

files=("$api_env")
if [[ $validation_mode == "full" ]]; then
  files+=("$agent_env")
fi
for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing protected environment file: $file" >&2
    exit 1
  fi
  permissions=$(stat -c '%a' "$file")
  if (( 10#$permissions > 600 )); then
    echo "$file must have mode 0600 or stricter" >&2
    exit 1
  fi
done

set -a
. "$api_env"
set +a

required_api=(
  NODE_ENV PANEL_ORIGIN DATABASE_URL DATABASE_SSL_CA SESSION_COOKIE_DOMAIN WEBAUTHN_RP_ID
  WEBAUTHN_ORIGIN CREDENTIAL_ENCRYPTION_KEY CSRF_SECRET
  CLOUDFLARE_OAUTH_CLIENT_ID CLOUDFLARE_OAUTH_CLIENT_SECRET CLOUDFLARE_OAUTH_REDIRECT_URI
  GITHUB_APP_ID GITHUB_APP_SLUG GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET
  GITHUB_APP_PRIVATE_KEY_BASE64 GITHUB_WEBHOOK_SECRET ACME_EMAIL
)
for name in "${required_api[@]}"; do
  if [[ -z ${!name:-} ]]; then
    echo "Missing API setting: $name" >&2
    exit 1
  fi
done
if [[ ! -r $DATABASE_SSL_CA ]]; then
  echo "Cannot read API database CA certificate: $DATABASE_SSL_CA" >&2
  exit 1
fi
if [[ $NODE_ENV != "production" || $PANEL_ORIGIN != https://* || $WEBAUTHN_ORIGIN != https://* ]]; then
  echo "Production mode and HTTPS panel/WebAuthn origins are required" >&2
  exit 1
fi
if [[ ${#CSRF_SECRET} -lt 32 || ${#GITHUB_WEBHOOK_SECRET} -lt 32 ]]; then
  echo "CSRF_SECRET and GITHUB_WEBHOOK_SECRET must contain at least 32 characters" >&2
  exit 1
fi
decoded_key_bytes=$(printf '%s' "$CREDENTIAL_ENCRYPTION_KEY" | base64 -d 2>/dev/null | wc -c)
if [[ $decoded_key_bytes -ne 32 ]]; then
  echo "CREDENTIAL_ENCRYPTION_KEY must decode to exactly 32 bytes" >&2
  exit 1
fi

if [[ $validation_mode == "full" ]]; then
  unset LH_API_URL LH_NODE_ID LH_AGENT_TOKEN
  set -a
  . "$agent_env"
  set +a
  for name in LH_API_URL LH_NODE_ID LH_AGENT_TOKEN; do
    if [[ -z ${!name:-} ]]; then
      echo "Missing agent setting: $name" >&2
      exit 1
    fi
  done
  if [[ $LH_API_URL != https://* || ${#LH_AGENT_TOKEN} -lt 32 ]]; then
    echo "The agent requires an HTTPS API URL and a strong node token" >&2
    exit 1
  fi
fi

echo "Production environment validation passed without printing secret values."
