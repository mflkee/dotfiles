#!/bin/bash

# Получаем использование памяти (в процентах)
mem_total=$(free -m | awk '/Mem:/ {print $2}')
mem_used=$(free -m | awk '/Mem:/ {print $3}')
mem_percentage=$((mem_used * 100 / mem_total))

# Определение цветов
COLOR1="#8cc85f" # до 50% использования (зеленый)
COLOR2="#e3c78a" # от 50% до 80% (оранжевый)
COLOR3="#ff5d5d" # выше 80% (красный)

# Выбор цвета в зависимости от использования памяти
if [[ "$mem_percentage" -ge 80 ]]; then
  COLOR=$COLOR3
elif [[ "$mem_percentage" -ge 50 ]]; then
  COLOR=$COLOR2
else
  COLOR=$COLOR1
fi

# Иконка из Hack Nerd Font
ICON=""

# Вывод в формате Polybar
echo "%{T4}%{F$COLOR}$ICON%{T1}%{F-} %{F$COLOR}$mem_percentage%%{F-}"
