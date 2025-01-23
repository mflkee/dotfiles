#!/bin/bash

# Проверим статус vpn
vpn_pid=$(pgrep -o openvpn)

active="%{F#8BE9FD}"
disabled="%{F#FF5555}"

if [[ -n $vpn_pid ]]; then
    echo "${active}%{T12}VPN%{F-}"
else
    echo "${disabled}%{T12}VPN%{F-}"
fi
