#!/usr/bin/env bash
set -euo pipefail

# Auto-assign workspaces depending on monitor count.
# - Dual monitors: external (non-eDP) gets 1..5, laptop eDP gets 6..10
# - Single monitor: all 1..10 map to the only monitor

log() {
  printf '[auto-setup] %s\n' "$*" >&2
}

readarray -t MONS < <(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')

if (( ${#MONS[@]} == 0 )); then
  # hyprctl monitors -j may not be ready yet; sleep and retry once
  sleep 0.3
  readarray -t MONS < <(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
fi

if (( ${#MONS[@]} == 0 )); then
  log "No monitors detected by hyprctl yet; skipping"
  exit 0
fi

# Identify internal (eDP/LVDS) vs external
internal=""
externals=()
for m in "${MONS[@]}"; do
  if [[ "$m" =~ (?i)edp|lvds ]]; then
    internal="$m"
  else
    externals+=("$m")
  fi
done

if (( ${#MONS[@]} == 1 )); then
  main="${MONS[0]}"
  log "Single monitor: $main -> workspaces 1..10"
  for i in {1..10}; do
    hyprctl keyword "workspace" "$i,monitor:$main" >/dev/null
  done
  exit 0
fi

# Prefer the first non-internal as the big/external display
external=""
if (( ${#externals[@]} > 0 )); then
  external="${externals[0]}"
fi

# If no eDP found (desktop with two externals), just split 1..5 left-most, 6..10 right-most
if [[ -z "$internal" && -n "$external" ]]; then
  log "Two externals (no eDP): ${externals[*]} -> 1..5 on ${externals[0]}, 6..10 on ${externals[1]:-${externals[0]}}"
  left="${externals[0]}"
  right="${externals[1]:-${externals[0]}}"
  for i in {1..5}; do hyprctl keyword workspace "$i,monitor:$left" >/dev/null; done
  for i in {6..10}; do hyprctl keyword workspace "$i,monitor:$right" >/dev/null; done
  exit 0
fi

if [[ -n "$external" && -n "$internal" ]]; then
  log "Dual monitors: external=$external -> 1..5, internal=$internal -> 6..10"
  for i in {1..5}; do hyprctl keyword workspace "$i,monitor:$external" >/dev/null; done
  for i in {6..10}; do hyprctl keyword workspace "$i,monitor:$internal" >/dev/null; done
fi

exit 0

