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

if [ -n "$(git -C blackbox-log-viewer status --short)" ]; then
  echo "blackbox-log-viewer has local changes. It is read-only in this workspace." >&2
  exit 1
fi

if [ -n "$(git -C betaflight status --short)" ]; then
  echo "betaflight has local changes. It is read-only in this workspace." >&2
  exit 1
fi

git add .gitignore .gitmodules README.md AGENTS.md CLAUDE.md .agents scripts Assets Airframe blackbox-log-viewer betaflight
git commit -m "$1"
