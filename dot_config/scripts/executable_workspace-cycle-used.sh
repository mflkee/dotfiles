#!/usr/bin/env bash
set -euo pipefail

direction="${1:-next}"
if [[ "$direction" != "next" && "$direction" != "prev" ]]; then
  echo "Usage: $0 [next|prev]" >&2
  exit 2
fi

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

active_json="$(hyprctl activeworkspace -j 2>/dev/null || true)"
if [[ -z "$active_json" ]]; then
  exit 0
fi

current_ws="$(jq -r '.id // empty' <<<"$active_json")"
monitor_id="$(jq -r '.monitorID // empty' <<<"$active_json")"
if [[ -z "$current_ws" || -z "$monitor_id" ]]; then
  exit 0
fi

# Cycle only workspaces with windows on the focused monitor.
mapfile -t ws_ids < <(
  hyprctl workspaces -j 2>/dev/null \
    | jq -r --argjson mon "$monitor_id" '
        [
          .[]
          | select((.id // 0) > 0)
          | select((.monitorID // -1) == $mon)
          | select((.windows // 0) > 0)
          | .id
        ]
        | sort
        | unique
        | .[]
      '
)

# Keep current workspace in the ring even when it's empty.
if [[ "${#ws_ids[@]}" -eq 0 ]]; then
  ws_ids=("$current_ws")
elif ! printf '%s\n' "${ws_ids[@]}" | grep -qx "$current_ws"; then
  ws_ids+=("$current_ws")
  mapfile -t ws_ids < <(printf '%s\n' "${ws_ids[@]}" | sort -n -u)
fi

count="${#ws_ids[@]}"
(( count == 0 )) && exit 0

index=-1
for i in "${!ws_ids[@]}"; do
  if [[ "${ws_ids[$i]}" == "$current_ws" ]]; then
    index="$i"
    break
  fi
done

(( index < 0 )) && index=0

if [[ "$direction" == "next" ]]; then
  target_index=$(( (index + 1) % count ))
else
  target_index=$(( (index - 1 + count) % count ))
fi

target_ws="${ws_ids[$target_index]}"
if [[ "$target_ws" != "$current_ws" ]]; then
  hyprctl dispatch workspace "$target_ws" >/dev/null 2>&1 || true
fi
