#!/bin/sh
# Per-machine overrides for noctalia settings
# Applied after theme restore via dsync sync

SETTINGS="$HOME/.config/noctalia/settings.json"
[ -f "$SETTINGS" ] || exit 0

HOSTNAME=$(hostname)

case "$HOSTNAME" in
    archlinux-notebook*)
        python3 -c "
import json
with open('$SETTINGS') as f:
    cfg = json.load(f)
cfg['networkPanelView'] = 'wifi'
cfg['bluetoothAutoConnect'] = True
with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null
        ;;
    *)
        # Default overrides for all machines
        python3 -c "
import json
with open('$SETTINGS') as f:
    cfg = json.load(f)
cfg['notifications']['enableKeyboardLayoutToast'] = False
with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null
        ;;
esac
