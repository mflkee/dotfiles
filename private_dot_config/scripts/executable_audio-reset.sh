#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Restarting PipeWire stack (user)…"
systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service || true
sleep 1.5

echo "[2/5] Unloading leftover PulseAudio modules (loopback/null-sink)…"
if command -v pactl >/dev/null 2>&1; then
  pactl list short modules 2>/dev/null | awk '/module-loopback|module-null-sink/ {print $1}' | xargs -r -n1 pactl unload-module || true
fi

echo "[3/5] Resetting defaults and volumes via wpctl…"
if command -v wpctl >/dev/null 2>&1; then
  # Try to pick the first sink if default is missing
  def_sink_id=$(wpctl status 2>/dev/null | awk '/Sinks:/{flag=1;next}/Sources:/{flag=0}flag && $1 ~ /^[0-9]+\./ {print $1}' | sed 's/\.$//' | head -n1)
  if [[ -n "${def_sink_id:-}" ]]; then
    wpctl set-default "$def_sink_id" || true
  fi
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || true
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 || true
  wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1.0 || true
fi

echo "[4/5] Cleaning recorder temp state…"
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/rec_mix.env" || true

echo "[5/5] Done. Try playing audio (e.g. with mpv) and report back."

