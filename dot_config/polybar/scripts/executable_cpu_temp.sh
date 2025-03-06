#!/bin/bash

{{ if eq .chezmoi.hostname "arch-desktop" }}
temp=$(sensors | awk '/k10temp-pci-00c3/,/^$/{if ($0 ~ /Tctl:/) {print $2}}' | sed 's/[^0-9.]//g' | head -1)
{{ else if eq .chezmoi.hostname "arch-thinkpad" }}
temp=$(sensors | awk '/coretemp-isa-0000/,/^$/{if ($0 ~ /Core 0/) {print $3}}' | sed 's/[^0-9.]//g' | head -1)
{{ end }}

temp=${temp%.*}  # Удаляем десятичную часть

# Определение цветов для текста и иконки
COLOR1="#50FA7B" # до 60 (зеленый)
COLOR2="#FFB86C" # от 60 до 80 (оранжевый)
COLOR3="#FF5555" # выше 80 (красный)

# Выбор иконки в зависимости от температуры
if [[ "$temp" -ge 80 ]]; then
  ICON="%{T14}%{T-}"  # Иконка для высокой температуры
  COLOR=$COLOR3
elif [[ "$temp" -ge 60 ]]; then
  ICON="%{T14}%{T-}"  # Иконка для средней температуры
  COLOR=$COLOR2
else
  ICON="%{T14}%{T-}"  # Иконка для низкой температуры
  COLOR=$COLOR1
fi

# Вывод иконки и температуры с соответствующим цветом
echo "%{F$COLOR}$ICON%{F-} %{F$COLOR}$temp°C%{F-}"
