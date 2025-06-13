#!/bin/bash

VPN_NAME="OpenVPN Connection"

active="%{F#8BE9FD}%{T11}VPN%{F-}"
disabled="%{F#FF5555}%{T11}VPN%{F-}"

if nmcli connection show --active | grep -q "$VPN_NAME"; then
    echo "$active"
else
    echo "$disabled"
fi
