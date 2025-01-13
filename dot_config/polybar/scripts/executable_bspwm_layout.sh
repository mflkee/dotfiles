#!/bin/bash

# Получаем состояние клиента на текущем рабочем столе
client_state=$(bspc query -T -d "$(bspc query -D -d)" | jq -r '.root.client.state')

# Формируем вывод и применяем цвета
case $client_state in
    floating)
        echo -e "%{F#C4746E}[floating]"
        ;;
    pseudo_tiled)
        echo -e "%{F#E6C384}[pseudo_tiled]"
        ;;
    fullscreen)
        echo -e "%{F#7FB4CA}[fullscreen]"
        ;;
    *) # в противном случае возвращаем layout рабочего стола
        layout=$(bspc query -T -d "$(bspc query -D -d)" | jq -r '.layout')
        echo "%{F#87A987}[$layout]"
        ;;
esac

