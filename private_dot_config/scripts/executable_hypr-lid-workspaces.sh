#!/usr/bin/env bash
set -euo pipefail

# Switch workspace-to-monitor routing when laptop lid changes state.
# close: use external monitor as single display with workspaces 1..10
# open: restore split layout 1..5 on internal, 6..10 on external

mode="${1:-}"
if [[ "$mode" != "close" && "$mode" != "open" ]]; then
  echo "Usage: $0 [close|open]" >&2
  exit 2
fi

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

hyprctl_try() {
  local out=""

  out="$(hyprctl "$@" 2>/dev/null || true)"
  if [[ -n "$out" ]] && [[ "$out" != "Couldn't set socket timeout (2)" ]]; then
    printf '%s\n' "$out"
    return 0
  fi

  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    out="$(HYPRLAND_INSTANCE_SIGNATURE="$(basename "$dir")" hyprctl "$@" 2>/dev/null || true)"
    if [[ -n "$out" ]] && [[ "$out" != "Couldn't set socket timeout (2)" ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  done < <(ls -1dt "$runtime_dir"/hypr/* 2>/dev/null || true)

  return 1
}

hyprctl_do() {
  hyprctl_try "$@" >/dev/null 2>&1 || true
}

restart_waybar_async() {
  command -v waybar >/dev/null 2>&1 || return 0
  (
    sleep 0.7
    pkill -x waybar >/dev/null 2>&1 || true
    nohup waybar >/tmp/waybar.log 2>&1 &
  ) >/dev/null 2>&1 &
}

read_monitors_json() {
  local out
  local i
  for ((i = 0; i < 14; i++)); do
    out="$(hyprctl_try monitors -j || true)"
    if jq -e . >/dev/null 2>&1 <<<"$out"; then
      printf '%s\n' "$out"
      return 0
    fi
    sleep 0.2
  done
  printf '[]\n'
}

get_internal_monitor() {
  local json="$1"
  jq -r '[.[] | .name | select(test("^(eDP|LVDS)"))][0] // empty' <<<"$json"
}

get_external_monitor() {
  local json="$1"
  jq -r '
    (
      [ .[] | select((.name | test("^(eDP|LVDS)")) | not) | select(.focused == true) | .name ] +
      [ .[] | select((.name | test("^(eDP|LVDS)")) | not) | .name ]
    )[0] // empty
  ' <<<"$json"
}

set_workspace_monitor() {
  local ws="$1"
  local mon="$2"
  hyprctl_do keyword workspace "${ws}, monitor:${mon}"
}

assign_all_to_monitor() {
  local mon="$1"
  local ws
  for ws in {1..10}; do
    set_workspace_monitor "$ws" "$mon"
  done
}

assign_split_layout() {
  local internal="$1"
  local external="$2"
  local ws
  for ws in {1..5}; do
    set_workspace_monitor "$ws" "$internal"
  done
  for ws in {6..10}; do
    set_workspace_monitor "$ws" "$external"
  done
}

wait_for_external_monitor() {
  local tries=8
  local i json external
  for ((i = 0; i < tries; i++)); do
    json="$(read_monitors_json)"
    external="$(get_external_monitor "$json")"
    if [[ -n "$external" ]]; then
      printf '%s\n' "$external"
      return 0
    fi
    sleep 0.2
  done
  return 1
}

case "$mode" in
  close)
    monitors_json="$(read_monitors_json)"
    internal_monitor="$(get_internal_monitor "$monitors_json")"
    external_monitor="$(wait_for_external_monitor || true)"

    # No external display: keep current setup.
    [[ -n "$external_monitor" ]] || exit 0

    if [[ -n "$internal_monitor" ]]; then
      hyprctl_do keyword monitor "${internal_monitor}, disable"
    fi

    assign_all_to_monitor "$external_monitor"
    hyprctl_do dispatch workspace 1
    restart_waybar_async
    ;;

  open)
    monitors_json="$(read_monitors_json)"
    internal_monitor="$(get_internal_monitor "$monitors_json")"
    external_monitor="$(get_external_monitor "$monitors_json")"

    # If we can detect internal panel, make sure it is enabled again.
    if [[ -n "$internal_monitor" ]]; then
      # Keep same scale as monitors.conf.tmpl for laptop panel.
      hyprctl_do keyword monitor "${internal_monitor}, preferred, auto, 1.5"
    fi

    # If no external monitor, route all workspaces to internal.
    if [[ -z "$external_monitor" ]]; then
      [[ -n "$internal_monitor" ]] && assign_all_to_monitor "$internal_monitor"
      exit 0
    fi

    if [[ -n "$internal_monitor" ]]; then
      assign_split_layout "$internal_monitor" "$external_monitor"
    else
      assign_all_to_monitor "$external_monitor"
    fi
    restart_waybar_async
    ;;
esac
