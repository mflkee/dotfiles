#!/usr/bin/env bash
set -euo pipefail

# Toggle recording on Wayland/Hyprland with tofi-driven setup.
# Video flow (Super+Shift+R):
#   1) Выберите экран (монитор)
#   2) Включить микрофон? (Да/Нет)
#   3) Включить системный звук? (Да/Нет)
#   4) Качество (FPS)
#   => wf-recorder (или wl-screenrec) + (опционально) виртуальный микс микрофон+система
# Audio-only flow (Super+Shift+M):
#   - Источник (Система/Микрофон)
#   - Качество MP3 (128k/192k/256k/320k)

MODE="${1:-video}"

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
videos_dir="${XDG_VIDEOS_DIR:-$HOME/videos}"
music_dir="${XDG_MUSIC_DIR:-$HOME/music}"
[[ -d "$music_dir" ]] || music_dir="$videos_dir"

mkdir -p "$state_dir" "$videos_dir" "$music_dir" 2>/dev/null || true

# Will be set per-mode before first use
pid_file=""
last_file=""

is_running() {
  [[ -n "$pid_file" ]] || return 1
  [[ -f "$pid_file" ]] || return 1
  local pid comm
  pid=$(cat "$pid_file" 2>/dev/null || true)
  [[ -n "${pid:-}" ]] || { rm -f "$pid_file"; return 1; }
  if kill -0 "$pid" 2>/dev/null; then
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d '\n' || true)
    case "$comm" in
      wf-recorder|wl-screenrec|ffmpeg) return 0 ;;
      *) rm -f "$pid_file"; return 1 ;;
    esac
  else
    rm -f "$pid_file"; return 1
  fi
}

tofi_pick() {
  # Usage: tofi_pick "Prompt" "opt1" "opt2" ...
  local prompt="$1"; shift
  local sel=""
  # Use tofi only to keep look identical to your app launcher
  if command -v tofi >/dev/null 2>&1; then
    # Respect your drun style entirely (single row, theme-controlled)
    sel=$(printf '%s\n' "$@" | tofi --multi-instance=true --prompt-text "$prompt" 2>/dev/null || true)
  else
    notify-send "Запись экрана" "tofi не установлен — выбор параметров недоступен"
  fi
  printf '%s' "${sel%$'\n'}"
}

pick_bool() { local ans; ans=$(tofi_pick "$1" "Да" "Нет"); [[ -z "$ans" ]] && ans="Нет"; [[ "$ans" == "Да" ]] && echo yes || echo no; }

pick_video_fps() {
  local ans; ans=$(tofi_pick "Качество (FPS)" "30" "60");
  case "$ans" in 60) echo 60 ;; 30) echo 30 ;; *) echo 30 ;; esac
}

pick_mp3_bitrate() {
  local ans; ans=$(tofi_pick "Качество MP3" "192k" "128k" "256k" "320k")
  case "$ans" in 128k|192k|256k|320k) echo "$ans" ;; *) echo 192k ;; esac
}

pick_monitor() {
  local mons sel
  if command -v jq >/dev/null 2>&1; then
    mons=$(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' || true)
  else
    mons=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
  fi
  if [[ -z "$mons" ]]; then
    echo ""; return 0
  fi
  sel=$(tofi_pick "Выберите экран" $mons)
  if [[ -z "$sel" ]]; then
    sel=$(printf '%s\n' $mons | head -n1)
  fi
  printf '%s' "$sel"
}

resolve_audio_dev() {
  local mode="${1:-system}" dev="" sink=""
  # If PulseAudio (pipewire-pulse) is not reachable, fallback to no audio
  if ! pactl info >/dev/null 2>&1; then
    printf '%s' ""; return 0
  fi
  local get_active_sink
  get_active_sink() {
    local sid name
    sid=$(pactl list short sink-inputs 2>/dev/null | awk 'NR==1{print $2}')
    if [[ -n "$sid" ]]; then
      name=$(pactl list short sinks 2>/dev/null | awk -v id="$sid" '$1==id{print $2}')
      [[ -n "$name" ]] && { printf '%s' "$name"; return 0; }
    fi
    pactl get-default-sink 2>/dev/null || true
  }
  if [[ "$mode" == "mic" ]]; then
    dev=$(pactl get-default-source 2>/dev/null || true)
  elif [[ "$mode" == "system" ]]; then
    sink=$(get_active_sink)
    [[ -n "$sink" ]] && dev="${sink}.monitor"
  fi
  printf '%s' "${dev}"
}

# Track and switch default PulseAudio source safely
get_default_source() {
  pactl info 2>/dev/null | awk -F': ' '/Default Source/{print $2}'
}

set_default_source() {
  local new_src="$1"; [[ -n "$new_src" ]] || return 1
  pactl set-default-source "$new_src" 2>/dev/null || true
}

push_default_source() {
  local current
  current=$(get_default_source || true)
  echo "PREV_SRC=$current" >"$state_dir/rec_audio.env"
}

pop_default_source() {
  local f="$state_dir/rec_audio.env"; [[ -r "$f" ]] || return 0
  # shellcheck disable=SC1090
  source "$f" || true
  [[ -n "${PREV_SRC:-}" ]] && pactl set-default-source "$PREV_SRC" 2>/dev/null || true
  rm -f "$f"
}

create_mix_sink() {
  # Create a null sink and loopbacks for mic + system with safe latency.
  local sink_name="rec_mix_$(date +%s)" sink_mod mic lb1 lb2 sink
  # Prefer active playback sink if any, else default sink
  local sid name
  sid=$(pactl list short sink-inputs 2>/dev/null | awk 'NR==1{print $2}')
  if [[ -n "$sid" ]]; then
    name=$(pactl list short sinks 2>/dev/null | awk -v id="$sid" '$1==id{print $2}')
    sink="$name"
  else
    sink=$(pactl get-default-sink 2>/dev/null || true)
  fi
  mic=$(pactl get-default-source 2>/dev/null || true)
  if [[ -z "$mic" || -z "$sink" ]]; then
    echo ""; return 1
  fi
  sink_mod=$(pactl load-module module-null-sink \
    sink_name="$sink_name" rate=48000 channels=2 \
    sink_properties=device.description="$sink_name" 2>/dev/null || true)
  [[ -n "$sink_mod" ]] || { echo ""; return 1; }
  lb1=$(pactl load-module module-loopback \
    source="$mic" sink="$sink_name" latency_msec=20 adjust_time=1 remix=1 2>/dev/null || true)
  lb2=$(pactl load-module module-loopback \
    source="${sink}.monitor" sink="$sink_name" latency_msec=20 adjust_time=1 remix=1 2>/dev/null || true)
  echo "SINK_NAME=$sink_name" >"$state_dir/rec_mix.env"
  echo "SINK_MOD=$sink_mod" >>"$state_dir/rec_mix.env"
  echo "LB1_MOD=$lb1" >>"$state_dir/rec_mix.env"
  echo "LB2_MOD=$lb2" >>"$state_dir/rec_mix.env"
  printf '%s.monitor' "$sink_name"
}

cleanup_mix_sink() {
  local f="$state_dir/rec_mix.env"; [[ -r "$f" ]] || return 0
  # shellcheck disable=SC1090
  source "$f" || true
  [[ -n "${LB1_MOD:-}" ]] && pactl unload-module "$LB1_MOD" 2>/dev/null || true
  [[ -n "${LB2_MOD:-}" ]] && pactl unload-module "$LB2_MOD" 2>/dev/null || true
  [[ -n "${SINK_MOD:-}" ]] && pactl unload-module "$SINK_MOD" 2>/dev/null || true
  rm -f "$f"
}

start_video() {
  local ts outfile recorder_pid audio_mode fps dev="" fps_arg=() audio_args=() vf_args=()
  ts=$(date +'%Y-%m-%d-%H%M%S')
  outfile="$videos_dir/record_${ts}.mp4"

  # Clean up any stale virtual mix from previous runs
  cleanup_mix_sink || true
  pop_default_source || true

  # Один выбор: источник звука (в стиле твоего tofi, короткие метки)
  audio_mode=$(tofi_pick "Источник звука" \
    "Mic+Sys" \
    "Mic" \
    "Sys" \
    "Mute")
  # Escape/close -> отмена без записи
  if [[ -z "$audio_mode" ]]; then
    notify-send "Запись экрана" "Отменено"; return 0
  fi
  case "$audio_mode" in
    "Mic+Sys") dev=$(create_mix_sink) ;;
    "Mic") dev=$(resolve_audio_dev mic) ;;
    "Sys") dev=$(resolve_audio_dev system) ;;
    "Mute") dev="" ;;
    *) dev="" ;;
  esac
  fps=30
  fps_arg=( -r "$fps" )
  if [[ -n "$dev" ]]; then
    # Ensure wf-recorder uses the intended source even if it ignores -a
    push_default_source
    set_default_source "$dev"
    audio_args=( -a "$dev" )
  fi
  local audio_codec_args=()
  if [[ -n "$dev" ]]; then
    audio_codec_args=( -C aac )
  fi
  # yuv420p для совместимости
  vf_args=( -F "format=yuv420p" )

  if command -v wf-recorder >/dev/null 2>&1; then
    wf-recorder \
      -D -y \
      "${fps_arg[@]}" \
      "${audio_args[@]}" \
      "${vf_args[@]}" \
      "${audio_codec_args[@]}" \
      -c libx264 \
      -x yuv420p \
      -p crf=23 \
      -p preset=veryfast \
      -p tune=zerolatency \
      -p profile=main \
      -p level=4.0 \
      -f "$outfile" >/dev/null 2>&1 &
    recorder_pid=$!
  elif command -v wl-screenrec >/dev/null 2>&1; then
    wl-screenrec -f "$outfile" >/dev/null 2>&1 &
    recorder_pid=$!
  else
    notify-send "Запись экрана" "Не найден wf-recorder или wl-screenrec"
    cleanup_mix_sink
    exit 1
  fi

  echo "$recorder_pid" > "$pid_file"
  echo "$outfile" > "$last_file"
  notify-send "Запись экрана" "Началась запись: $(basename "$outfile") — ${fps} FPS"
}

start_audio() {
  local ts outfile recorder_pid audio_pick mode dev br
  ts=$(date +'%Y-%m-%d-%H%M%S')
  outfile="$music_dir/audio_${ts}.mp3"
  audio_pick=$(tofi_pick "Источник аудио (MP3)" "Система" "Микрофон")
  [[ -z "$audio_pick" ]] && audio_pick="Система"
  case "$audio_pick" in "Система") mode=system ;; "Микрофон") mode=mic ;; *) mode=system ;; esac
  br=$(pick_mp3_bitrate)
  dev=$(resolve_audio_dev "$mode")
  if [[ -z "$dev" ]]; then
    notify-send "Запись аудио" "Не удалось определить аудио-устройство"
    exit 1
  fi
  ffmpeg -hide_banner -loglevel error -f pulse -i "$dev" -c:a libmp3lame -b:a "$br" "$outfile" >/dev/null 2>&1 &
  recorder_pid=$!
  echo "$recorder_pid" > "$pid_file"
  echo "$outfile" > "$last_file"
  notify-send "Запись аудио" "Начата: $(basename "$outfile") — $br"
}

stop_rec() {
  local pid
  pid=$(cat "$pid_file" 2>/dev/null || true)
  if [[ -n "${pid:-}" ]]; then
    # SIGINT works for both wf-recorder and ffmpeg
    kill -INT "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
  if [[ -f "$last_file" ]]; then
    if [[ "$MODE" == "audio" ]]; then
      notify-send "Запись аудио" "Остановлена: $(basename "$(cat "$last_file")")"
    else
      notify-send "Запись экрана" "Остановлена: $(basename "$(cat "$last_file")")"
    fi
  else
    notify-send "Запись" "Остановлена"
  fi
  # Clean up virtual audio mix (if any)
  cleanup_mix_sink
  # Restore default source
  pop_default_source || true
}

if [[ "$MODE" == "audio" ]]; then
  pid_file="$state_dir/audiorec.pid"
  last_file="$state_dir/audiorec.last"
  if is_running; then
    stop_rec
  else
    start_audio
  fi
else
  pid_file="$state_dir/screenrec.pid"
  last_file="$state_dir/screenrec.last"
  if is_running; then
    stop_rec
  else
    start_video
  fi
fi
