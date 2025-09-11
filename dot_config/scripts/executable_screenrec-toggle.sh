#!/usr/bin/env bash
set -euo pipefail

# Toggle screen recording on Wayland/Hyprland.
# Prefers wf-recorder, falls back to wl-screenrec.
# Saves to ~/video and exposes status via ~/.cache/screenrec.pid

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
pid_file="$state_dir/screenrec.pid"
last_file="$state_dir/screenrec.last"
out_dir="$HOME/video"
mkdir -p "$state_dir" "$out_dir"

is_running() {
  [[ -f "$pid_file" ]] || return 1
  local pid
  pid=$(cat "$pid_file" 2>/dev/null || true)
  [[ -n "${pid:-}" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

start_rec() {
  ts=$(date +'%Y-%m-%d-%H%M%S')
  outfile="$out_dir/record_${ts}.mkv"

  if command -v wf-recorder >/dev/null 2>&1; then
    # Full screen recording. If needed, change to: -g "$(slurp)"
    wf-recorder -f "$outfile" >/dev/null 2>&1 &
    echo $! > "$pid_file"
  elif command -v wl-screenrec >/dev/null 2>&1; then
    wl-screenrec -f "$outfile" >/dev/null 2>&1 &
    echo $! > "$pid_file"
  else
    notify-send "Запись экрана" "Не найден wf-recorder или wl-screenrec"
    exit 1
  fi

  echo "$outfile" > "$last_file"
  notify-send "Запись экрана" "Началась запись: $(basename "$outfile")"
}

stop_rec() {
  local pid
  pid=$(cat "$pid_file" 2>/dev/null || true)
  if [[ -n "${pid:-}" ]]; then
    # SIGINT is the graceful stop for wf-recorder
    kill -INT "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
  if [[ -f "$last_file" ]]; then
    notify-send "Запись экрана" "Остановлена: $(basename "$(cat "$last_file")")"
  else
    notify-send "Запись экрана" "Остановлена"
  fi
}

if is_running; then
  stop_rec
else
  start_rec
fi

