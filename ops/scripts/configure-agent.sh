#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [[ ${EUID} -ne 0 || ! -t 0 ]]; then
  echo "Run interactively as root" >&2
  exit 1
fi

target=/etc/legacy-hosting/agent.env
if [[ -e "$target" ]]; then
  echo "$target already exists; move it to a protected backup before re-enrolling" >&2
  exit 1
fi

read -r -p "Node ID shown by the panel: " node_id
read -r -s -p "Node token shown once by the panel: " node_token
printf '\n'
if [[ ! $node_id =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ || ${#node_token} -lt 32 || $node_token == *\'* ]]; then
  echo "Invalid node ID or token" >&2
  exit 1
fi

install -d -m 0700 /etc/legacy-hosting
temporary=$(mktemp /etc/legacy-hosting/.agent.env.XXXXXX)
trap 'rm -f -- "$temporary"' EXIT
{
  printf "LH_API_URL='https://api.legacyhosting.xyz/api/v1'\n"
  printf "LH_NODE_ID='%s'\n" "$node_id"
  printf "LH_AGENT_TOKEN='%s'\n" "$node_token"
  printf "LH_HEARTBEAT_INTERVAL_MS='30000'\n"
  printf "LH_COMMAND_POLL_INTERVAL_MS='2000'\n"
} > "$temporary"
chmod 0600 "$temporary"
mv "$temporary" "$target"
trap - EXIT
echo "Created $target with mode 0600. Run activate-agent.sh next."
