#!/bin/bash

# Наборы иконок
icons_empty=(󰎦 󰎩 󰎬 󰎮 󰎰 󰎵 󰎸 󰎻 󰎾)  # Иконки для пустых рабочих столов
icons_single=(󰎤 󰎧 󰎪 󰎭 󰎱 󰎳 󰎶 󰎹 󰎼)   # Иконки для одного окна
icons_multi=(󰼏 󰼐 󰼑 󰼒 󰼓 󰼔 󰼕 󰼖 󰼗)   # Иконки для двух и более окон

# Цвета
color_empty="#6272A4"    # Цвет для пустых рабочих столов
color_single="#FFB86C"   # Цвет для одного окна
color_multi="#FF79C6"    # Цвет для двух и более окон
color_focused="#50FA7B"  # Цвет для активного рабочего стола
underline_color="#8BE9FD" # Цвет подчеркивания для активного рабочего стола

# Размер шрифта
font_size="%{T13}"

# Получение информации о рабочих столах
workspaces=$(bspc query -D --names)          # Список всех рабочих столов
active_ws=$(bspc query -D -d focused --names) # Активный рабочий стол

output=""
for ws in $workspaces; do
    # Список окон на рабочем столе
    windows=$(bspc query -N -d "$ws")

    if [ -z "$windows" ]; then
        # Пустой рабочий стол
        icon="${icons_empty[$((ws-1))]}"
        color=$color_empty
    else
        # Проверяем количество окон
        window_count=$(echo "$windows" | wc -l)
        if [ "$window_count" -eq 1 ]; then
            icon="${icons_single[$((ws-1))]}"
            color=$color_single
        else
            icon="${icons_multi[$((ws-1))]}"
            color=$color_multi
        fi
    fi

    # Добавление подчеркивания и цвета для активного рабочего стола
    if [ "$ws" == "$active_ws" ]; then
        output+="%{F$color_focused}%{u$underline_color}%{+u}${font_size}$icon%{-u}%{F-} "
    else
        output+="%{F$color}${font_size}$icon%{F-} "
    fi
done

echo "$output"
