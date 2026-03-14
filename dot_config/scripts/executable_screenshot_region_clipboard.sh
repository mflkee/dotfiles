#!/usr/bin/env bash
set -euo pipefail

# Select region on any monitor, save PNG and copy to clipboard
# Requires: slurp grim wl-copy

outdir="${SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}"
mkdir -p "$outdir"
filename="screenshot_$(date +'%Y-%m-%d-%H%M%S').png"
filepath="$outdir/$filename"

command -v slurp >/dev/null 2>&1 || exit 1
command -v grim >/dev/null 2>&1 || exit 1
command -v wl-copy >/dev/null 2>&1 || exit 1

region="$(slurp 2>/dev/null || true)"
[ -n "$region" ] || exit 0

if ! grim -g "$region" - | tee "$filepath" | wl-copy --type image/png >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Ошибка создания скриншота"
  exit 0
fi

command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Сохранён и скопирован: $(basename "$filepath")"
