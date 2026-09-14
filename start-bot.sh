#!/usr/bin/env bash
# One-click launcher (Linux / macOS) for the paper-trading bot.
# Live market data by default; add --demo to run offline.
set -euo pipefail
cd "$(dirname "$0")"

# Auto-update: fast-forward to the latest version when possible (offline-safe).
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  echo "Checking for updates…"
  git pull --ff-only --quiet 2>/dev/null || true
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 trading_bot/bot.py "$@"
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)'; then
  exec python trading_bot/bot.py "$@"
else
  echo "Python 3 is required — https://www.python.org/downloads/"
  exit 1
fi
