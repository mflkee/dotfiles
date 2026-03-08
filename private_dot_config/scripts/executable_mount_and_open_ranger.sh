#!/bin/bash

MOUNT_POINT="/media/usb"
DEVICE=$1

# Монтируем устройство
sudo udevil mount $DEVICE

# Запускаем ranger в alacritty
alacritty -e ranger $MOUNT_POINT
