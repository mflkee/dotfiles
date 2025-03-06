#!/bin/bash

# Получаем свободное место на диске (в гигабайтах)
disk_free=$(df -h /home | awk 'NR==2 {print $4}')

# Получаем процент использования диска (для цветовой индикации)
disk_usage=$(df -h /home | awk 'NR==2 {print $5}' | sed 's/%//g')

# Определение цветов
COLOR1="#50FA7B" # до 50% использования (зеленый)
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

# Иконка из Nerd Fonts (󰋊 — диск)
ICON="󰋊"

# Вывод в формате Polybar: свободное место + цвет по использованию
echo "%{T3}%{F$COLOR}$ICON%{T-}%{F-} %{F$COLOR}${disk_free}%{F-}"
