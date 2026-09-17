#!/usr/bin/env bash
set -Eeuo pipefail

base=/opt/legacy-hosting
test -L "$base/current"
test -f "$base/current-release"
test -f /var/www/legacy-hosting-panel/index.html
curl --fail --silent --show-error http://127.0.0.1:8080/health | grep -q '"database":"connected"'
pm2 describe lh-api >/dev/null
pm2 describe lh-certificate-worker >/dev/null
pm2 describe lh-monitoring-worker >/dev/null
if [[ -f /etc/legacy-hosting/agent.env ]]; then
  pm2 describe lh-agent >/dev/null
else
  echo "Agent enrollment is pending; API/panel stage only."
fi
current_release=$(readlink -f "$base/current")
CURRENT_RELEASE="$current_release" node <<'NODE'
const { execFileSync } = require("node:child_process");

const currentRelease = process.env.CURRENT_RELEASE;
const processes = JSON.parse(execFileSync("pm2", ["jlist"], { encoding: "utf8" }));
const required = ["lh-api", "lh-certificate-worker", "lh-monitoring-worker"];
if (require("node:fs").existsSync("/etc/legacy-hosting/agent.env")) {
  required.push("lh-agent");
}
for (const name of required) {
  const processInfo = processes.find((item) => item.name === name);
  const scriptPath = processInfo?.pm2_env?.pm_exec_path;
  if (!scriptPath?.startsWith(`${currentRelease}/`)) {
    throw new Error(`${name} is not running from ${currentRelease}`);
  }
}
NODE
nginx -t
echo "Release verification passed for $(cat "$base/current-release")."
