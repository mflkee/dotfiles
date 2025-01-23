#!/bin/bash

# Получаем загруженность CPU (100% - %idle)
cpu_idle=$(mpstat 1 1 | awk '/Average:/ && $12 ~ /[0-9.]+/ {print 100 - $12}')
cpu_usage=${cpu_idle%.*}  # Удаляем десятичную часть

# Определение цветов
COLOR1="#50FA7B" # до 50% (зеленый)
COLOR2="#FFB86C" # от 50% до 80% (оранжевый)
COLOR3="#FF5555" # выше 80% (красный)

# Выбор цвета в зависимости от загруженности
if [[ "$cpu_usage" -ge 80 ]]; then
  COLOR=$COLOR3
elif [[ "$cpu_usage" -ge 50 ]]; then
  COLOR=$COLOR2
else
  COLOR=$COLOR1
fi

# Иконка из Hack Nerd Font
ICON=""

# Вывод в формате Polybar
echo "%{T14}%{F$COLOR}$ICON%{T1}%{F-} %{F$COLOR}$cpu_usage%%{F-}"
