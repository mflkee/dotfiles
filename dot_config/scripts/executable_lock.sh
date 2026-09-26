#!/usr/bin/env bash
# Lock screen: blurred snapshot of the current screen.
#   grim (capture) → blur (magick/convert/ffmpeg) → swaylock -i
# Фолбэки: если снимок/блюр не удались — лок ВСЕГДА запускается (без картинки).
#   Раньше set -e убивал скрипт до swaylock, и экран оставался незаблокированным.
# Цвета индикатора: ~/.config/swaylock/config (акцент Noctalia).

shot="${XDG_RUNTIME_DIR:-/tmp}/swaylock-$(id -u).png"

img=""
# 1) Снимок экрана (с таймаутом — grim не должен висеть)
if timeout 5 grim "$shot" 2>/dev/null && [ -s "$shot" ]; then
  img="$shot"
  # 2) Блюр любым доступным инструментом (неудача не фатальна)
  if command -v magick >/dev/null 2>&1; then
    magick "$shot" -filter Gaussian -blur 0x8 "$shot" 2>/dev/null || true
  elif command -v convert >/dev/null 2>&1; then
    convert "$shot" -filter Gaussian -blur 0x8 "$shot" 2>/dev/null || true
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -loglevel error -i "$shot" -vf "gblur=sigma=8" "$shot" 2>/dev/null || true
  fi
  # Если блюр испортил файл — лок без картинки
  [ -s "$shot" ] || img=""
fi

# 2.5) Пароль должен вводиться в EN-раскладке: в русской пароль «ломается»,
#     ошибки ввода уходят в pam_faillock и банят учётку на ~10 минут.
niri msg action switch-layout 0 >/dev/null 2>&1 || true

# 3) Лок ВСЕГДА запускается
if [ -n "$img" ]; then
  exec swaylock -f -i "$img"
fi
exec swaylock -f