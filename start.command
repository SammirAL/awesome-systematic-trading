#!/usr/bin/env bash
# macOS double-click launcher — delegates to start.sh.
cd "$(dirname "$0")"
exec ./start.sh "$@"
