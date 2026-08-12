#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <commit-message>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -n "$(git -C Airframe status --short)" ]; then
  echo "Airframe has local changes. Commit or stash them inside Airframe before root commits." >&2
  exit 1
fi

if [ -n "$(git -C upstreams/blackbox-log-viewer status --short)" ]; then
  echo "blackbox-log-viewer has local changes. It is read-only in this workspace." >&2
  exit 1
fi

if [ -n "$(git -C upstreams/betaflight status --short)" ]; then
  echo "betaflight has local changes. It is read-only in this workspace." >&2
  exit 1
fi

if [ -n "$(git -C upstreams/betaflight-configurator status --short)" ]; then
  echo "betaflight-configurator has local changes. It is read-only in this workspace." >&2
  exit 1
fi

if [ -n "$(git -C upstreams/PIDtoolbox status --short)" ]; then
  echo "PIDtoolbox has local changes. It is read-only in this workspace." >&2
  exit 1
fi

git add .gitattributes .gitignore .gitmodules README.md AGENTS.md CLAUDE.md .agents fixtures knowledge marketing tools Airframe upstreams
git commit -m "$1"
