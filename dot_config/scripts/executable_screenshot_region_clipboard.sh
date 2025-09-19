#!/usr/bin/env bash
set -euo pipefail

# Take a region screenshot, save to ~/screenshots and copy to clipboard
# Requires: hyprshot

outdir="$HOME/screenshots"
mkdir -p "$outdir"
filename="screenshot_$(date +'%Y-%m-%d-%H%M%S').png"

# Run capture allowing cancel without error spam
set +e
hyprshot -m region -o "$outdir" -f "$filename"
rc=$?
set -e

if [[ $rc -ne 0 || ! -s "$outdir/$filename" ]]; then
  command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Отменено"
  exit 0
fi
