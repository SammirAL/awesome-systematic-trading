#!/usr/bin/env bash
# Re-sync the bundled content assets from the repository root.
# Run from anywhere: tool/sync_assets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
cp ../README.md ../README_zh.md assets/content/
cp ../static/images/awesome-systematic-trading.jpeg assets/images/
rm -f assets/strategies/*
cp ../static/strategies/* assets/strategies/
echo "assets synced: $(ls assets/strategies | wc -l) strategies"
