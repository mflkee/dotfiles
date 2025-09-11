#!/usr/bin/env bash
set -euo pipefail

pid_file="${XDG_CACHE_HOME:-$HOME/.cache}/screenrec.pid"

if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file" 2>/dev/null || echo 0)" 2>/dev/null; then
  # Red filled circle
  printf '{"text":"●","class":"recording"}\n'
else
  printf '{"text":"","class":"idle"}\n'
fi

