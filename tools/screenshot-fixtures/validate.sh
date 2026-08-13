#!/bin/sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
exec swift run --package-path "$workspace/tools/screenshot-fixtures" screenshot-fixtures validate "$workspace/fixtures/screenshots/manifest.json"
