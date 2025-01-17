#!/bin/bash

# Переключение состояния микрофона
amixer set Capture toggle

# Проверка состояния микрофона
MIC_STATE=$(amixer get Capture | grep -o '\[on\]' | head -n 1 | wc -l)

# Вывод состояния микрофона
echo "MIC_STATE: $MIC_STATE"

# Включение или выключение светодиода
if [ "$MIC_STATE" -eq "1" ]; then
    echo "Turning LED on"
    echo 1 | sudo tee /sys/devices/platform/thinkpad_acpi/leds/platform::micmute/brightness
else
    echo "Turning LED off"
    echo 0 | sudo tee /sys/devices/platform/thinkpad_acpi/leds/platform::micmute/brightness
fi
