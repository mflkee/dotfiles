#!/bin/bash

state=$(nmcli radio wifi)

echo "Current Wi-Fi state: $state"

if [[ "$state" == "enabled" ]]; then
    echo "Turning Wi-Fi off"
    nmcli radio wifi off
else
    echo "Turning Wi-Fi on"
    nmcli radio wifi on
fi
