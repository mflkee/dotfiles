#!/bin/bash

# Цвета
color_floating="#FFB86C"   # Цвет для floating
color_pseudo_tiled="#F1FA8C" # Цвет для pseudo_tiled
color_fullscreen="#44475A"  # Цвет для fullscreen
color_monocle="#FF79C6"     # Цвет для monocle
color_tiled="#BD93F9"       # Цвет для tiled
color_unknown="#87A987"     # Цвет для неизвестного layout

# Размер шрифта
font_size="%{T13}"

# Получаем состояние клиента на текущем рабочем столе
client_state=$(bspc query -T -d "$(bspc query -D -d)" | jq -r '.root.client.state')

# Формируем вывод и применяем цвета
case $client_state in
    floating)
        echo -e "%{F$color_floating}${font_size}󰯻"  # Значок для floating
        ;;
    pseudo_tiled)
        echo -e "%{F$color_pseudo_tiled}${font_size}󰬛"  # Значок для pseudo_tiled
        ;;
    fullscreen)
        echo -e "%{F$color_fullscreen}${font_size}󰯺"  # Значок для fullscreen
        ;;
    monocle)
        echo -e "%{F$color_monocle}${font_size}󰰏"  # Значок для monocle
        ;;
    *) # в противном случае возвращаем layout рабочего стола
        layout=$(bspc query -T -d "$(bspc query -D -d)" | jq -r '.layout')
        case $layout in
            tiled)
                echo -e "%{F$color_tiled}${font_size}󰰤"  # Значок для tiled
                ;;
            monocle)
                echo -e "%{F$color_monocle}${font_size}󰰏"  # Значок для monocle
                ;;
            *)
                echo -e "%{F$color_unknown}${font_size}[$layout]"  # Если layout неизвестен, выводим его как есть
                ;;
        esac
        ;;
esac
