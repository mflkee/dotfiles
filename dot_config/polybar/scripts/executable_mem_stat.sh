#!/bin/bash

# Получаем использование диска (в процентах) для корневой файловой системы (/)
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//g')

# Определение цветов
COLOR1="#50FA7B" # до 50% (зеленый)
COLOR2="#FFB86C" # от 50% до 80% (оранжевый)
COLOR3="#FF5555" # выше 80% (красный)

# Выбор цвета в зависимости от использования диска
if [[ "$disk_usage" -ge 80 ]]; then
  COLOR=$COLOR3
elif [[ "$disk_usage" -ge 50 ]]; then
  COLOR=$COLOR2
else
  COLOR=$COLOR1
fi

# Иконка из Hack Nerd Font
ICON="󰆼"

# Вывод в формате Polybar
echo "%{T3}%{F$COLOR}$ICON%{T-}%{F-} %{F$COLOR}$disk_usage%%%{F-}"
