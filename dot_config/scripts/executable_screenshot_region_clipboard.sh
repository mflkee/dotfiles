#!/usr/bin/env bash
set -euo pipefail

# Take a region screenshot, save to ~/screenshots and copy to clipboard
# Requires: hyprshot

outdir="$HOME/screenshots"
mkdir -p "$outdir"
filename="screenshot_$(date +'%Y-%m-%d-%H%M%S').png"

hyprshot -m region -o "$outdir" -f "$filename"

