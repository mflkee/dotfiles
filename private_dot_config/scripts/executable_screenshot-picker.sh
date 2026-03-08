#!/usr/bin/env bash
set -euo pipefail

outdir="${XDG_PICTURES_DIR:-$HOME/screenshots}"
mkdir -p "$outdir"
ts=$(date +'%Y-%m-%d-%H%M%S')

tofi_pick() {
  local prompt="$1"; shift
  local sel=""
  if command -v tofi >/dev/null 2>&1; then
    sel=$(printf '%s\n' "$@" | tofi --multi-instance=true --prompt-text "$prompt" 2>/dev/null || true)
  else
    printf '%s' "$1"
  fi
  printf '%s' "${sel%$'\n'}"
}

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "$1" || true; }
copy_clip() { local f="$1"; command -v wl-copy >/dev/null 2>&1 && wl-copy < "$f" || true; }

mode=$(tofi_pick "Источник снимка" "Оба" "Монитор" "Область")
if [[ -z "$mode" ]]; then
  notify "Отменено"
  exit 0
fi

case "$mode" in
  "Оба")
    file="$outdir/screenshot_${ts}.png"
    if command -v grim >/dev/null 2>&1; then
      if command -v wl-copy >/dev/null 2>&1; then
        grim - | tee "$file" | wl-copy >/dev/null 2>&1 || true
      else
        grim "$file"
      fi
      notify "Сохранён: $(basename "$file")"
    else
      notify "grim не найден"; exit 1
    fi
    ;;
  "Монитор")
    mons=""
    if command -v jq >/dev/null 2>&1; then
      mons=$(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' || true)
    else
      mons=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
    fi
    [[ -z "$mons" ]] && { notify "Мониторы не найдены"; exit 1; }
    pick=$(tofi_pick "Монитор" $mons)
    if [[ -z "$pick" ]]; then
      notify "Отменено"
      exit 0
    fi
    file="$outdir/screenshot_${pick}_${ts}.png"
    if command -v hyprshot >/dev/null 2>&1; then
      hyprshot -m output -m "$pick" -o "$outdir" -f "$(basename "$file")"
      copy_clip "$file"; notify "Сохранён: $(basename "$file")"
    elif command -v grim >/dev/null 2>&1; then
      if command -v wl-copy >/dev/null 2>&1; then
        grim -o "$pick" - | tee "$file" | wl-copy >/dev/null 2>&1 || true
      else
        grim -o "$pick" "$file"
      fi
      notify "Сохранён: $(basename "$file")"
    else
      notify "Нет hyprshot/grim"; exit 1
    fi
    ;;
  "Область")
    file="$outdir/screenshot_${ts}.png"
    if command -v hyprshot >/dev/null 2>&1; then
      set +e
      hyprshot -m region -o "$outdir" -f "$(basename "$file")"
      rc=$?
      set -e
      if [[ $rc -ne 0 || ! -s "$file" ]]; then
        notify "Отменено"; exit 0
      fi
      copy_clip "$file"; notify "Сохранён: $(basename "$file")"
    elif command -v slurp >/dev/null 2>&1 && command -v grim >/dev/null 2>&1; then
      region=$(slurp 2>/dev/null || true)
      if [[ -z "$region" ]]; then
        notify "Отменено"
        exit 0
      fi
      if command -v wl-copy >/dev/null 2>&1; then
        grim -g "$region" - | tee "$file" | wl-copy >/dev/null 2>&1 || true
      else
        grim -g "$region" "$file"
      fi
      notify "Сохранён: $(basename "$file")"
    else
      notify "Нет hyprshot/slurp/grim"; exit 1
    fi
    ;;
esac
