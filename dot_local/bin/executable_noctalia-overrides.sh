#!/bin/sh
# Per-machine overrides for noctalia settings
# Applied after theme restore via dsync sync

SETTINGS="$HOME/.config/noctalia/settings.json"
[ -f "$SETTINGS" ] || exit 0

# All machines: disable keyboard layout toast
python3 -c "
import json
with open('$SETTINGS') as f:
    cfg = json.load(f)
cfg['notifications']['enableKeyboardLayoutToast'] = False
with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null

# Per-machine overrides
case "$(uname -n)" in
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
esac
