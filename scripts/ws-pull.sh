#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

git pull --ff-only
git submodule sync
git submodule update --init

git -C Airframe fetch --all --prune

git -C blackbox-log-viewer remote set-url --push origin DISABLED
git -C betaflight remote set-url --push origin DISABLED

git -C blackbox-log-viewer pull --ff-only
git -C betaflight pull --ff-only

git status --short
git submodule status
