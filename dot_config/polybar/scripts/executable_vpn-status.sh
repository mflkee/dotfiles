#!/bin/bash

VPN_NAME="OpenVPN Connection"

active="%{F#8BE9FD}%{T11}VPN%{F-}%{T0}"  # Крупный шрифт для активного состояния
disabled="%{F#FF5555}%{T11}VPN%{F-}%{T0}"  # Крупный шрифт для неактивного состояния

if nmcli connection show --active | grep -q "$VPN_NAME"; then
    echo "$active"
else
    echo "$disabled"
fi
