#!/bin/bash
# Auto-detect timezone via IP geolocation
# Managed by chezmoi - do not edit directly

IFACE=$(ip route show default 2>/dev/null | head -1 | grep -oP 'dev \K\S+')
CURRENT_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null)
API_TZ=$(curl -s --connect-timeout 5 --interface "$IFACE" http://ip-api.com/json/ 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin).get('timezone',''))")

if [ -n "$API_TZ" ] && [ "$API_TZ" != "$CURRENT_TZ" ]; then
    echo "[$HOSTNAME] Changing timezone: $CURRENT_TZ -> $API_TZ"
    timedatectl set-timezone "$API_TZ"
fi
