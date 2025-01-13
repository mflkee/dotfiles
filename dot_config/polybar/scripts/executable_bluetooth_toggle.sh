#!/bin/bash

# Установим пути для отладочных логов
log_file="/tmp/polybar_bluetooth_debug.log"

# Очистим файл логов перед запуском
> "$log_file"

echo "Running bluetooth_toggle.sh" >> "$log_file"

# Проверим состояние Bluetooth
state=$(bluetoothctl show | grep 'Powered:' | awk '{print $2}')
echo "Bluetooth state: $state" >> "$log_file"

# Прямо укажем цвета для теста
active="%{F#80a0ff}"
disabled="%{F#ff5454}"

if [[ "$state" == "yes" ]]; then
    echo "Bluetooth is on" >> "$log_file"
    echo "${active}%{T3}%{F-}"  # Выводим иконку с цветом "включено"
    exit 0  # Выходим из скрипта
fi

if [[ "$state" == "no" ]]; then 
    echo "Bluetooth is off" >> "$log_file"
    echo "${disabled}%{T3}󰂲%{F-}"  # Выводим иконку с цветом "выключено"
    exit 0  # Выходим из скрипта
fi

# Если состояние неопределённое, выведем сообщение об ошибке
echo "Unknown Bluetooth state: $state" >> "$log_file"
echo "Unknown"  # Выводим текстовый индикатор неопределённого состояния
exit 1
