#!/bin/bash

# Проверяем, есть ли процесс OpenVPN
vpn_pid=$(pgrep -o openvpn)

if [[ -n $vpn_pid ]]; then
    # Если процесс найден, VPN включен, выключаем его
    sudo killall openvpn
    # Ждем некоторое время, чтобы процесс успел завершиться
    sleep 2
else
    # Если процесс не найден, VPN выключен, запускаем его
    sudo openvpn --config /etc/openvpn/client.conf > /dev/null 2>&1 &
fi
