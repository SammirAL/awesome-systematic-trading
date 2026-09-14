#!/usr/bin/env bash
# Release web build that serves the CanvasKit engine from the build itself
# instead of Google's CDN — required for fully-local/offline use.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release
echo "→ build/web ready (serve with any static file server)"
