#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 VERSION [OUTPUT_DIRECTORY]" >&2
  exit 1
fi

version=$1
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Invalid semantic version: $version" >&2
  exit 1
fi

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
output_directory=${2:-$repository_root}
mkdir -p "$output_directory"
output_directory=$(cd "$output_directory" && pwd)

required_paths=(
  LH-API/dist
  LH-API/database
  LH-API/package.json
  LH-API/pnpm-lock.yaml
  LH-API/pnpm-workspace.yaml
  LH-API/ecosystem.config.cjs
  LH-Agent/dist
  LH-Agent/package.json
  LH-Agent/pnpm-lock.yaml
  LH-Agent/pnpm-workspace.yaml
  LH-Agent/ecosystem.config.cjs
  LH-Panel/dist/index.html
  ops
)
for path in "${required_paths[@]}"; do
  if [[ ! -e "$repository_root/$path" ]]; then
    echo "Release input is missing: $path" >&2
    exit 1
  fi
done

pnpm --dir "$repository_root/LH-API" build
pnpm --dir "$repository_root/LH-Agent" build
VITE_APP_VERSION="$version" pnpm --dir "$repository_root/LH-Panel" build

temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT
release_name="legacy-hosting-$version"
release_root="$temporary_directory/$release_name"
mkdir -p "$release_root/LH-API" "$release_root/LH-Agent" "$release_root/LH-Panel" "$release_root/ops"

cp -a "$repository_root"/LH-API/{dist,database,package.json,pnpm-lock.yaml,pnpm-workspace.yaml,ecosystem.config.cjs,.env.example,README.md,SERVER.md} "$release_root/LH-API/"
cp -a "$repository_root"/LH-Agent/{dist,package.json,pnpm-lock.yaml,pnpm-workspace.yaml,ecosystem.config.cjs,.env.example,README.md} "$release_root/LH-Agent/"
cp -a "$repository_root/LH-Panel/dist" "$repository_root/LH-Panel/package.json" "$release_root/LH-Panel/"
cp -a "$repository_root/ops/." "$release_root/ops/"
cp "$repository_root"/{ROADMAP.md,SECURITY.md,RELEASE.md,BACKUP.md} "$release_root/"
chmod 0755 "$release_root"/ops/scripts/*.sh

mkdir -p "$release_root/artifacts"
tar -C "$release_root/LH-Agent" -czf "$release_root/artifacts/lh-agent-runtime.tar.gz" \
  dist package.json pnpm-lock.yaml pnpm-workspace.yaml ecosystem.config.cjs
(cd "$release_root/artifacts" && sha256sum lh-agent-runtime.tar.gz > lh-agent-runtime.tar.gz.sha256)

{
  printf 'version=%s\n' "$version"
  printf 'platform_commit=%s\n' "$(git -C "$repository_root" rev-parse HEAD)"
  printf 'api_commit=%s\n' "$(git -C "$repository_root/LH-API" rev-parse HEAD)"
  printf 'agent_commit=%s\n' "$(git -C "$repository_root/LH-Agent" rev-parse HEAD)"
  printf 'panel_commit=%s\n' "$(git -C "$repository_root/LH-Panel" rev-parse HEAD)"
} > "$release_root/RELEASE-MANIFEST.txt"

archive="$output_directory/$release_name.tar.gz"
checksum="$archive.sha256"
tar -C "$temporary_directory" -czf "$archive" "$release_name"
(cd "$output_directory" && sha256sum "$release_name.tar.gz" > "$release_name.tar.gz.sha256")

echo "Created $archive"
echo "Created $checksum"
