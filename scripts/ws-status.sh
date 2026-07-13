#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Workspace root"
git status --short

echo
echo "Submodules"
git submodule status

echo
echo "Airframe"
git -C Airframe status --short

echo
echo "blackbox-log-viewer"
git -C blackbox-log-viewer status --short

echo
echo "betaflight"
git -C betaflight status --short
