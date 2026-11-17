#!/usr/bin/env bash
set -euo pipefail

# Скриншот области с аннотациями.
# Основной путь — встроенный аннотатор Noctalia (стрелка, текст, блюр, обрезка).
# Если Noctalia нет (например, на headless-машине) — обычный grim+slurp с копией в буфер.

outdir="${SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}"
mkdir -p "$outdir"

if command -v noctalia >/dev/null 2>&1; then
  exec noctalia msg screenshot-region \
    --annotate \
    --freeze-screen \
    --save-to-file \
    --copy-to-clipboard \
    --directory "$outdir" \
    --filename-pattern 'screenshot_%Y-%m-%d_%H-%M-%S'
fi

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
