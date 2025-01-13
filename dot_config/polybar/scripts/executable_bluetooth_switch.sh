#!/bin/bash

state=$(bluetoothctl show | grep 'State:' | awk '{print $2}')

if [[ "$state" == "on" ]]; then
    bluetoothctl power off
else
    bluetoothctl power on
fi

