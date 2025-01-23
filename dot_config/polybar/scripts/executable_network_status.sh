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
up="%{F#50FA7B}" 
down="%{F#FF5555}"
value="%{F#F8F8F2}"

# Получаем новые значения трафика
rx_new=$(cat /sys/class/net/"$interface"/statistics/rx_bytes)
tx_new=$(cat /sys/class/net/"$interface"/statistics/tx_bytes)

# Вычисляем разницу (трафик за 1 секунду)
rx_rate=$((($rx_new - $rx_old) * 8 / 1024)) 
tx_rate=$((($tx_new - $tx_old) * 8 / 1024))

# Выводим информацию
echo "${up}%{T3}%{T-}${value}$rx_rate Kb/s ${down}%{T3}%{T-}${value}$tx_rate Kb/s" 

