#!/bin/bash

# Получаем использование оперативной памяти (в процентах)
memory_usage=$(free | awk '/^Mem:/ {print $3/$2 * 100}' | awk '{printf "%d\n", $1}')

# Определение цветов
COLOR1="#50FA7B" # до 50% (зеленый)
COLOR2="#FFB86C" # от 50% до 80% (оранжевый)
COLOR3="#FF5555" # выше 80% (красный)

# Выбор цвета в зависимости от использования памяти
if [[ "$memory_usage" -ge 80 ]]; then
  COLOR=$COLOR3
elif [[ "$memory_usage" -ge 50 ]]; then
  COLOR=$COLOR2
else
  COLOR=$COLOR1
fi

# Иконка из Hack Nerd Font
ICON=""

# Вывод в формате Polybar
echo "%{T3}%{F$COLOR}$ICON%{T-}%{F-} %{F$COLOR}${memory_usage}%%{F-}"
