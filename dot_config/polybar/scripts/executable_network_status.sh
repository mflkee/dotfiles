#!/bin/bash

# Получаем список всех сетевых интерфейсов и их состояния
interfaces=$(ip link | awk '/state UP/ {print $2}' | tr -d ':')

# Выбираем первый активный интерфейс из списка
interface=$(echo "$interfaces" | head -n 1)

# Проверяем, найден ли интерфейс
if [ -z "$interface" ]; then
    echo "Активный сетевой интерфейс не найден."
    exit 1
fi

# Получаем текущие значения трафика
rx_old=$(cat /sys/class/net/"$interface"/statistics/rx_bytes)
tx_old=$(cat /sys/class/net/"$interface"/statistics/tx_bytes)

sleep 1 # Ждем 1 секунду

# Получаем текущие значения трафика
rx_old=$(cat /sys/class/net/"$interface"/statistics/rx_bytes)
tx_old=$(cat /sys/class/net/"$interface"/statistics/tx_bytes)

sleep 1 # Ждем 1 секунду
down="%{F#C4746E}" 
up="%{F#8A9A7B}"
value="%{F#C5C9C5}"

# Получаем новые значения трафика
rx_new=$(cat /sys/class/net/"$interface"/statistics/rx_bytes)
tx_new=$(cat /sys/class/net/"$interface"/statistics/tx_bytes)

# Вычисляем разницу (трафик за 1 секунду)
rx_rate=$((($rx_new - $rx_old) * 8 / 1024)) 
tx_rate=$((($tx_new - $tx_old) * 8 / 1024))

# Выводим информацию
echo "${up}%{T3}%{T-}${value}$rx_rate Kb/s ${down}%{T3}%{T-}${value}$tx_rate Kb/s" 

# color0 = #0D0C0C
# color1 = #8BC34A
# color2 = #8A9A7B
# color3 = #C4B28A
# color4 = #8BA4B0
# color5 = #A292A3
# color6 = #8EA4A2
# color7 = #C8C093
# color8 = #A6A69C
# color9 = #E46876
# color10 = #87A987
# color11 = #E6C384
# color12 = #7FB4CA
# color13 = #938AA9
# color14 = #7AA89F
# color15 = #C5C9C5
#
