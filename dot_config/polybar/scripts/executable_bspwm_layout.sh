#!/bin/bash

# Цвета
color_floating="#e3c78a"       # Color 4 (Yellow normal)
color_pseudo_tiled="#c6c684"   # Color 12 (Yellow bright)
color_fullscreen="#323437"     # Color 1 (Black normal)
color_monocle="#ff5189"       # Color 10 (Red bright)
color_tiled="#ae81ff"         # Color 14 (Purple bright)
color_unknown="#79dac8"       # Color 7 (Cyan normal)

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
