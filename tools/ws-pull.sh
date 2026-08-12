#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

git pull --ff-only
git submodule sync
git submodule update --init

git -C Airframe fetch --all --prune

git -C upstreams/blackbox-log-viewer remote set-url --push origin DISABLED
git -C upstreams/betaflight remote set-url --push origin DISABLED
git -C upstreams/betaflight-configurator remote set-url --push origin DISABLED
git -C upstreams/PIDtoolbox remote set-url --push origin DISABLED

git -C upstreams/blackbox-log-viewer pull --ff-only
git -C upstreams/betaflight pull --ff-only
git -C upstreams/PIDtoolbox pull --ff-only

git status --short
git submodule status
