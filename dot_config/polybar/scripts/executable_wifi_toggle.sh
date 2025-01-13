#!/bin/bash

# Установим пути для отладочных логов
log_file="/tmp/polybar_wifi_debug.log"

# Очистим файл логов перед запуском
> "$log_file"

echo "Running wifi_toggle.sh" >> "$log_file"

# Проверим состояние WiFi
state=$(nmcli radio wifi)
echo "WiFi state: $state" >> "$log_file"

# Прямо укажем цвета для теста
active="%{F#80a0ff}"
disabled="%{F#ff5454}"

if [[ "$state" == "enabled" ]]; then
    echo "WiFi is on" >> "$log_file"
    echo "${active}%{T6}%{F-}"  # Выводим иконку с цветом "включено"
    exit 0  # Выходим из скрипта
fi

if [[ "$state" == "disabled" ]]; then 
    echo "WiFi is off" >> "$log_file"
    echo "${disabled}%{T6}󰤮%{F-}"  # Выводим иконку с цветом "выключено"
    exit 0  # Выходим из скрипта
fi

# Если состояние неопределённое, выведем сообщение об ошибке
echo "Unknown WiFi state: $state" >> "$log_file"
echo "Unknown"  # Выводим текстовый индикатор неопределённого состояния
exit 1

# color0 = #0D0C0C
# color1 = #C4746E
# color2 = #8A9A7B
# color3 = #C4B28A
# color4 = #8BA4B0
# color5 = #A292A3
# color6 = #8EA4A2
# color7 = #C8C093
# color8 = #A6A69C
# color9 = #E46876
# color10 = #87A987
# color11 = #E6C384
# color12 = #7FB4CA
# color13 = #938AA9
# color14 = #7AA89F
# color15 = #C5C9C5
#
