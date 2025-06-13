#!/bin/bash

VPN_NAME="OpenVPN Connection"

if nmcli connection show --active | grep -q "$VPN_NAME"; then
    echo "$(date): Отключаю VPN..." >> ~/vpn-toggle.log
    nmcli connection down "$VPN_NAME"
    notify-send "VPN" "Отключен" -t 2000
else
    echo "$(date): Подключаю VPN..." >> ~/vpn-toggle.log
    nmcli connection up "$VPN_NAME"
    notify-send "VPN" "Подключен" -t 2000
fi
