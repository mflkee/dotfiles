#!/usr/bin/env bash
# Запись экрана для niri: gpu-screen-recorder + аудио + replay-буфер + OBS + скриншот.
#
#   screenrec-toggle.sh            — интерактивное меню (fuzzel)
#   screenrec-toggle.sh video      — старт/стоп записи видео
#   screenrec-toggle.sh replay     — старт/стоп replay-буфера (60 с)
#   screenrec-toggle.sh save       — сохранить клип из replay-буфера
#   screenrec-toggle.sh audio      — старт/стоп записи только звука (mp3)
#   screenrec-toggle.sh stop-all   — остановить всё
#   screenrec-toggle.sh status     — состояние + последние строки логов
#
# Требуется: gpu-screen-recorder + gsr-cli, fuzzel, slurp/grim, wl-copy,
#            notify-send, pactl, ffmpeg (только для аудио), опционально obs.
set -uo pipefail

MODE="${1:-menu}"

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/screenrec"
videos_dir="${XDG_VIDEOS_DIR:-$HOME/Videos}"
music_dir="${XDG_MUSIC_DIR:-$HOME/Music}"
replay_dir="$videos_dir/Replays"
shots_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$state_dir" "$videos_dir" "$replay_dir" "$shots_dir" 2>/dev/null || true

video_pid="$state_dir/video.pid"
video_sock="$runtime_dir/screenrec-video.sock"
video_out="$state_dir/video.out"
video_via_replay="$state_dir/video.via-replay"
video_log="$state_dir/video.log"

replay_pid_file="$state_dir/replay.pid"
replay_sock="$runtime_dir/screenrec-replay.sock"
replay_log="$state_dir/replay.log"

audio_pid="$state_dir/audiorec.pid"
audio_out="$state_dir/audiorec.out"
audio_log="$state_dir/audiorec.log"

FPS=60
QUALITY=very_high
CODEC=h264

# ---------------------------------------------------------------- утилиты ----

notify() {
  local title="$1" body="${2:-}"
  if [[ -n "$body" ]]; then
    notify-send -a "Запись экрана" "$title" "$body" 2>/dev/null || true
  else
    notify-send -a "Запись экрана" "$title" 2>/dev/null || true
  fi
}

# pick "Промпт" "строка1" "строка2" ... -> выбранный текст (пусто = отмена)
pick() {
  local prompt="$1"; shift
  local lines=$#
  (( lines > 12 )) && lines=12
  local out=""
  if command -v fuzzel >/dev/null 2>&1; then
    out=$(printf '%s\n' "$@" | fuzzel --dmenu --lines="$lines" --width=46 --prompt="$prompt  " 2>/dev/null) || out=""
  elif command -v rofi >/dev/null 2>&1; then
    out=$(printf '%s\n' "$@" | rofi -dmenu -p "$prompt" 2>/dev/null) || out=""
  else
    out="${1:-}"
  fi
  printf '%s' "$out"
}

index_of() { # index_of "значение" "${массив[@]}" -> индекс или -1
  local needle="$1"; shift
  local i=0
  for v in "$@"; do
    [[ "$v" == "$needle" ]] && { printf '%s' "$i"; return 0; }
    i=$((i + 1))
  done
  printf '%s' "-1"
}

pid_alive() {
  local f="$1" p
  [[ -r "$f" ]] || return 1
  p=$(cat "$f" 2>/dev/null || true)
  [[ -n "${p:-}" ]] || return 1
  kill -0 "$p" 2>/dev/null
}

video_running() {
  if [[ -f "$video_via_replay" ]]; then
    if pid_alive "$replay_pid_file"; then return 0; fi
    rm -f "$video_via_replay"; return 1
  fi
  if pid_alive "$video_pid"; then return 0; fi
  rm -f "$video_pid"; return 1
}

replay_running() {
  if pid_alive "$replay_pid_file"; then return 0; fi
  rm -f "$replay_pid_file"; return 1
}

audio_running() {
  if pid_alive "$audio_pid"; then return 0; fi
  rm -f "$audio_pid"; return 1
}

log_tail() { tail -n 3 "$1" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g'; }

# ------------------------------------------------------------------ аудио ----

# "NAME|DESCRIPTION" для реальных микрофонов (без мониторов), mic_clean первым.
list_mics() {
  pactl list sources 2>/dev/null | awk '
    /^Source #[0-9]/ { n=""; d="" }
    /^\tName: /        { n=$2 }
    /^\tDescription: / {
      d=$0; sub(/^\tDescription: /, "", d)
      if (n != "" && n !~ /\.monitor$/ && n !~ /^echo-cancel/)
        print n "|" d
    }
  ' | awk -F'|' '{ print ($1 == "mic_clean" ? 0 : 1) "|" $0 }' | sort -t'|' -k1,1n | cut -d'|' -f2-
}

default_mic() {
  local first
  first=$(list_mics | head -n1 | cut -d'|' -f1)
  printf '%s' "$first"
}

system_monitor() {
  local sink
  sink=$(pactl get-default-sink 2>/dev/null || true)
  [[ -n "$sink" ]] && printf '%s.monitor' "$sink"
}

# Заполняет AUDIO_ARGS для gpu-screen-recorder
AUDIO_ARGS=()
pick_audio() {
  local labels=("🔊 Система + микрофон" "🔊 Только система")
  local keys=("both" "system")
  local n d
  while IFS='|' read -r n d; do
    [[ -n "$n" ]] || continue
    labels+=("🎤 Только микрофон: $d")
    keys+=("mic:$n")
  done < <(list_mics)
  labels+=("🔇 Без звука")
  keys+=("mute")

  local sel idx
  sel=$(pick "Источник звука" "${labels[@]}")
  [[ -z "$sel" ]] && return 1
  idx=$(index_of "$sel" "${labels[@]}")
  (( idx < 0 )) && return 1
  local key="${keys[$idx]}"

  AUDIO_ARGS=()
  case "$key" in
    both)
      local mic; mic=$(default_mic)
      if [[ -n "$mic" ]]; then
        AUDIO_ARGS=(-a "default_output|$mic")
      else
        AUDIO_ARGS=(-a "default_output")
      fi
      ;;
    system) AUDIO_ARGS=(-a "default_output") ;;
    mute)   AUDIO_ARGS=() ;;
    mic:*)  AUDIO_ARGS=(-a "${key#mic:}") ;;
  esac
  if (( ${#AUDIO_ARGS[@]} > 0 )); then
    AUDIO_ARGS+=(-ac aac -ab 192)
  fi
  return 0
}

# --------------------------------------------------------------- источник ----

CAPTURE_ARGS=()
pick_source() {
  local labels=("🖥 Оба монитора")
  local keys=("BOTH")
  local name res
  while IFS='|' read -r name res; do
    [[ -n "$name" ]] || continue
    labels+=("🖥 Монитор $name ($res)")
    keys+=("MON:$name")
  done < <(gpu-screen-recorder --list-monitors 2>/dev/null || true)
  labels+=("🖥 Этот монитор (где курсор)" "✂️ Область (выделить мышью)")

  local sel idx
  sel=$(pick "Что записывать?" "${labels[@]}")
  [[ -z "$sel" ]] && return 1
  idx=$(index_of "$sel" "${labels[@]}")
  (( idx < 0 )) && return 1

  if (( idx == ${#keys[@]} )); then     # «этот монитор»
    local focused
    focused=$(niri msg --json focused-output 2>/dev/null | jq -r '.name' 2>/dev/null || true)
    ([ -z "$focused" ] || [ "$focused" = "null" ]) && focused=$(gpu-screen-recorder --list-monitors 2>/dev/null | head -n1 | cut -d'|' -f1)
    [[ -n "$focused" ]] || { notify "Запись" "Не удалось определить монитор"; return 1; }
    CAPTURE_ARGS=(-w "$focused")
    return 0
  fi
  if (( idx == ${#keys[@]} + 1 )); then # «область»
    local region
    region=$(slurp 2>/dev/null || true)
    [[ -n "$region" ]] || return 1
    CAPTURE_ARGS=(-w region -region "$region")
    return 0
  fi

  local key="${keys[$idx]}"
  case "$key" in
    BOTH)
      local args=() mon
      while IFS='|' read -r mon _; do
        [[ -n "$mon" ]] || continue
        args+=("$mon")
      done < <(gpu-screen-recorder --list-monitors 2>/dev/null || true)
      (( ${#args[@]} == 0 )) && { notify "Запись" "Мониторы не найдены"; return 1; }
      local joined
      joined=$(IFS='|'; printf '%s' "${args[*]}")
      CAPTURE_ARGS=(-w "$joined")
      ;;
    MON:*) CAPTURE_ARGS=(-w "${key#MON:}") ;;
    *) return 1 ;;
  esac
  return 0
}

# ------------------------------------------------------------------ видео ----

start_video() {
  if video_running; then stop_video; return 0; fi

  local out ts
  ts=$(date +'%Y-%m-%d_%H-%M-%S')

  # Если уже работает replay-буфер — пишем внутри него (экономит GPU).
  if replay_running; then
    if ! gsr-cli -ipc "$replay_sock" start-replay-recording >/dev/null 2>&1; then
      notify "Запись экрана" "Не удалось начать запись (replay-буфер)"; return 1
    fi
    : > "$video_via_replay"
    notify "⏺ Запись экрана" "Началась запись (вместе с replay-буфером)"
    return 0
  fi

  pick_source || { notify "Запись экрана" "Отменено"; return 0; }
  pick_audio  || { notify "Запись экрана" "Отменено"; return 0; }

  out="$videos_dir/record_$ts.mp4"
  rm -f "$video_sock" "$video_via_replay"
  gpu-screen-recorder \
    "${CAPTURE_ARGS[@]}" "${AUDIO_ARGS[@]}" \
    -k "$CODEC" -f "$FPS" -q "$QUALITY" -cursor yes -v no \
    -ipc "$video_sock" -o "$out" >"$video_log" 2>&1 &
  local p=$!
  echo "$p" > "$video_pid"
  echo "$out" > "$video_out"
  sleep 1.5
  if ! kill -0 "$p" 2>/dev/null; then
    local err; err=$(log_tail "$video_log")
    rm -f "$video_pid" "$video_out"
    notify "⛔ Запись не началась" "${err:-см. $video_log}"
    return 1
  fi
  notify "⏺ Запись экрана" "$(basename "$out") — ${FPS} FPS"
}

stop_video() {
  local out="" p
  if [[ -f "$video_via_replay" ]]; then
    out=$(gsr-cli -ipc "$replay_sock" stop-replay-recording 2>/dev/null | tail -n1)
    rm -f "$video_via_replay"
  else
    if pid_alive "$video_pid"; then
      out=$(gsr-cli -ipc "$video_sock" stop 2>/dev/null | tail -n1)
      if [[ -z "$out" ]]; then
        p=$(cat "$video_pid" 2>/dev/null || true)
        [[ -n "$p" ]] && kill -INT "$p" 2>/dev/null
        sleep 1
        out=$(cat "$video_out" 2>/dev/null || true)
      fi
    else
      out=$(cat "$video_out" 2>/dev/null || true)
    fi
    rm -f "$video_pid"
  fi
  if [[ -n "$out" ]]; then
    notify "⏹ Запись остановлена" "$(basename "$out")"
  else
    notify "⏹ Запись остановлена"
  fi
}

toggle_pause() {
  if [[ -f "$video_via_replay" ]]; then
    gsr-cli -ipc "$replay_sock" toggle-replay-recording >/dev/null 2>&1 || true
    notify "Запись" "Стоп/старт записи в replay-буфере"
    return 0
  fi
  video_running || { notify "Запись" "Запись не идёт"; return 0; }
  if gsr-cli -ipc "$video_sock" toggle-pause >/dev/null 2>&1; then
    notify "⏸ Запись" "Пауза переключена"
  else
    notify "Запись" "Пауза недоступна"
  fi
}

# ---------------------------------------------------------- replay-буфер ----

start_replay() {
  if replay_running; then stop_replay; return 0; fi
  if video_running; then
    notify "Replay-буфер" "Сначала остановите запись"; return 0
  fi
  pick_source || { notify "Запись экрана" "Отменено"; return 0; }
  pick_audio  || { notify "Запись экрана" "Отменено"; return 0; }

  rm -f "$replay_sock"
  gpu-screen-recorder \
    "${CAPTURE_ARGS[@]}" "${AUDIO_ARGS[@]}" \
    -k "$CODEC" -f "$FPS" -q "$QUALITY" -cursor yes -v no -c mp4 \
    -r 60 -replay-storage ram -o "$replay_dir" -ro "$videos_dir" -ipc "$replay_sock" >"$replay_log" 2>&1 &
  local p=$!
  echo "$p" > "$replay_pid_file"
  sleep 1.5
  if ! kill -0 "$p" 2>/dev/null; then
    local err; err=$(log_tail "$replay_log")
    rm -f "$replay_pid_file"
    notify "⛔ Replay-буфер не запустился" "${err:-см. $replay_log}"
    return 1
  fi
  notify "🔁 Replay-буфер включён" "Последние 60 с. Сохранение: Ctrl+Shift+R → «Сохранить клип» (или Alt+Shift+R)"
}

save_replay() {
  if ! replay_running; then
    notify "Клип не сохранён" "Replay-буфер не запущен (Ctrl+Shift+R → «Включить replay-буфер»)"
    return 0
  fi
  local out
  out=$(gsr-cli -ipc "$replay_sock" save-replay 2>/dev/null | tail -n1)
  if [[ -n "$out" ]]; then
    notify "💾 Клип сохранён" "$(basename "$out")"
  else
    notify "Клип не сохранён" "$(log_tail "$replay_log")"
  fi
}

stop_replay() {
  local out
  out=$(gsr-cli -ipc "$replay_sock" stop 2>/dev/null | tail -n1)
  if [[ -z "$out" ]] && pid_alive "$replay_pid_file"; then
    kill -INT "$(cat "$replay_pid_file")" 2>/dev/null || true
  fi
  rm -f "$replay_pid_file" "$video_via_replay"
  notify "⏹ Replay-буфер выключен"
}

# ------------------------------------------------------------------ аудио ----

start_audio() {
  if audio_running; then stop_audio; return 0; fi

  local labels=("🔊 Система" ) keys=("system")
  local n d
  while IFS='|' read -r n d; do
    [[ -n "$n" ]] || continue
    labels+=("🎤 Микрофон: $d"); keys+=("mic:$n")
  done < <(list_mics)

  local sel idx dev=""
  sel=$(pick "Что писать (MP3)" "${labels[@]}")
  [[ -z "$sel" ]] && { notify "Запись аудио" "Отменено"; return 0; }
  idx=$(index_of "$sel" "${labels[@]}")
  (( idx < 0 )) && return 0
  case "${keys[$idx]}" in
    system) dev=$(system_monitor) ;;
    mic:*)  dev="${keys[$idx]#mic:}" ;;
  esac
  if [[ -z "$dev" ]]; then
    notify "⛔ Запись аудио" "Не удалось определить аудио-устройство"
    return 1
  fi

  local out ts
  ts=$(date +'%Y-%m-%d_%H-%M-%S')
  out="$music_dir/audio_$ts.mp3"
  ffmpeg -hide_banner -loglevel error -f pulse -i "$dev" -c:a libmp3lame -b:a 192k "$out" >"$audio_log" 2>&1 &
  local p=$!
  echo "$p" > "$audio_pid"
  echo "$out" > "$audio_out"
  sleep 1
  if ! kill -0 "$p" 2>/dev/null; then
    local err; err=$(log_tail "$audio_log")
    rm -f "$audio_pid"
    notify "⛔ Запись аудио не началась" "${err:-см. $audio_log}"
    return 1
  fi
  notify "🎙 Запись аудио (MP3)" "$(basename "$out") — 192 kbps"
}

stop_audio() {
  local p out
  if pid_alive "$audio_pid"; then
    p=$(cat "$audio_pid" 2>/dev/null || true)
    [[ -n "$p" ]] && kill -INT "$p" 2>/dev/null
    sleep 1
  fi
  rm -f "$audio_pid"
  out=$(cat "$audio_out" 2>/dev/null || true)
  notify "⏹ Запись аудио остановлена" "$(basename "${out:-запись}")"
}

stop_all() {
  video_running && stop_video
  replay_running && stop_replay
  audio_running && stop_audio
  notify "⏹ Остановлено" "Все записи завершены"
}

# ------------------------------------------------------------------- меню ----

menu() {
  local items=()
  if video_running; then items+=("⏹ Остановить запись" "⏸ Пауза / продолжить")
  else items+=("⏺ Начать запись экрана"); fi
  if replay_running; then items+=("💾 Сохранить клип (replay)" "⏹ Выключить replay-буфер")
  else items+=("🔁 Включить replay-буфер (60 с)"); fi
  if audio_running; then items+=("⏹ Остановить аудиозапись")
  else items+=("🎙 Записать только звук (MP3)"); fi
  items+=("📸 Скриншот области" "🖥 Открыть OBS Studio" "⏹⏹ Остановить всё" "❌ Отмена")

  local sel
  sel=$(pick "Запись экрана" "${items[@]}")
  case "$sel" in
    "⏺ Начать запись экрана")        start_video ;;
    "⏹ Остановить запись")           stop_video ;;
    "⏸ Пауза / продолжить")          toggle_pause ;;
    "🔁 Включить replay-буфер (60 с)") start_replay ;;
    "💾 Сохранить клип (replay)")     save_replay ;;
    "⏹ Выключить replay-буфер")      stop_replay ;;
    "🎙 Записать только звук (MP3)")  start_audio ;;
    "⏹ Остановить аудиозапись")      stop_audio ;;
    "📸 Скриншот области")
      setsid --fork sh "$HOME/.config/scripts/screenshot_region_clipboard.sh" >/dev/null 2>&1 ;;
    "🖥 Открыть OBS Studio")
      if command -v obs >/dev/null 2>&1; then
        setsid --fork obs >/dev/null 2>&1
      else
        notify "OBS Studio" "obs не установлен: sudo pacman -S obs-studio"
      fi ;;
    "⏹⏹ Остановить всё")             stop_all ;;
    *) exit 0 ;;
  esac
}

status() {
  local s=""
  if video_running; then
    if [[ -f "$video_via_replay" ]]; then
      s+="видео: ЗАПИСЬ (внутри replay-процесса)\n"
    else
      s+="видео: ЗАПИСЬ ($(basename "$(cat "$video_out" 2>/dev/null)" 2>/dev/null))\n"
    fi
  else
    s+="видео: стоп\n"
  fi
  replay_running && s+="replay: ВКЛ (60 с)\n" || s+="replay: выкл\n"
  if audio_running; then
    s+="аудио: ЗАПИСЬ ($(basename "$(cat "$audio_out" 2>/dev/null)" 2>/dev/null))\n"
  else
    s+="аудио: стоп\n"
  fi
  printf '%b' "$s"
  printf 'video log: %s\n' "$(log_tail "$video_log")"
  printf 'replay log: %s\n' "$(log_tail "$replay_log")"
}

case "$MODE" in
  menu|"")  menu ;;
  video)    start_video ;;
  replay)   start_replay ;;
  save)     save_replay ;;
  audio)    start_audio ;;
  stop-all) stop_all ;;
  status)   status ;;
  *)        echo "usage: $(basename "$0") [menu|video|replay|save|audio|stop-all|status]" >&2; exit 2 ;;
esac
