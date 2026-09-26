#!/usr/bin/env bash
set -euo pipefail

# Lock screen: blurred snapshot of the current screen.
#   grim (capture) → blur (magick/convert/ffmpeg) → swaylock -i
# Цвета индикатора: ~/.config/swaylock/config (акцент Noctalia).
# Требования: grim, swaylock, один из blur-инструментов.

shot="${XDG_RUNTIME_DIR:-/tmp}/swaylock-$(id -u).png"

grim "$shot"

if command -v magick >/dev/null 2>&1; then
  magick "$shot" -filter Gaussian -blur 0x8 "$shot"
elif command -v convert >/dev/null 2>&1; then
  convert "$shot" -filter Gaussian -blur 0x8 "$shot"
else
  ffmpeg -y -loglevel error -i "$shot" -vf "gblur=sigma=8" "$shot"
fi

exec swaylock -f -i "$shot"