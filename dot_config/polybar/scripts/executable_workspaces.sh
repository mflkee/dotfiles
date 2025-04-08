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

# Определение текущего монитора
current_monitor=${MONITOR:-$(bspc query -M -m focused --names)}

# Получаем все рабочие столы
all_workspaces=($(bspc query -D --names))

# Определяем диапазон рабочих столов
if [ "$current_monitor" = "eDP-1" ]; then
    # Если это основной монитор
    if xrandr | grep -q "HDMI-1 connected"; then
        workspace_range=({1..5})  # Только 1-5 при подключенном втором мониторе
    else
        workspace_range=("${all_workspaces[@]}")  # Все рабочие столы при отключенном втором мониторе
    fi
elif [ "$current_monitor" = "HDMI-1" ]; then
    workspace_range=({6..9})  # Только 6-9 для второго монитора
fi

output=""
for ws in ${workspace_range[@]}; do
    # Проверяем, существует ли рабочий стол
    if ! echo "${all_workspaces[@]}" | grep -q "$ws"; then
        continue
    fi

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

    # Проверка активности рабочего стола
    active_ws=$(bspc query -D -d focused --names)
    if [ "$ws" = "$active_ws" ]; then
        output+="%{F$color_focused}%{u$underline_color}%{+u}${font_size}$icon%{-u}%{F-} "
    else
        output+="%{F$color}${font_size}$icon%{F-} "
    fi
done

echo "$output"
