#!/usr/bin/env bash
# One-click launcher (Linux / macOS) for the Awesome Systematic Trading local app.
# Zero dependencies: only needs Python 3 (falls back to Docker if Python is absent).
set -euo pipefail
cd "$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
  exec python3 local_app/server.py "$@"
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)'; then
  exec python local_app/server.py "$@"
elif command -v docker >/dev/null 2>&1; then
  echo "Python 3 not found — starting with Docker instead…"
  docker compose up --build
else
  echo "─────────────────────────────────────────────────────────────"
  echo "  Python 3 (or Docker) is required to run this app."
  echo "  Python 3 (ou Docker) est requis pour lancer cette application."
  echo "  → https://www.python.org/downloads/"
  echo "─────────────────────────────────────────────────────────────"
  exit 1
fi
