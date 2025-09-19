#!/usr/bin/env bash
set -euo pipefail

# Toggle XKB layout for all keyboards via hyprctl.
# Works around inconsistent grp:win_space_toggle by handling Super+Space in Hypr binds.

toggle_with_python() {
  python3 - "$@" << 'PY'
import json, subprocess, sys
try:
    out = subprocess.check_output(["hyprctl","-j","devices"])  # bytes
    j = json.loads(out)
    for kb in j.get("keyboards", []):
        name = kb.get("name")
        if name:
            subprocess.run(["hyprctl","switchxkblayout", name, "next"], check=False)
except Exception as e:
    sys.exit(1)
PY
}

if ! toggle_with_python; then
  # Fallback: parse text output
  mapfile -t names < <(hyprctl devices | awk '/Keyboard/ && $1=="Keyboard" {inKB=1} inKB && /^\s*Name:/ {sub("Name: ","",$0); print $0} /^\S/ && $1!="Name:" {inKB=0}')
  for n in "${names[@]:-}"; do
    [[ -n "$n" ]] && hyprctl switchxkblayout "$n" next || true
  done
fi

exit 0

