#!/bin/bash

# Получаем курс Bitcoin к доллару
btc_usd=$(curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd' | jq -r '.bitcoin.usd')

# Получаем курс USDT к рублю
usdt_rub=$(curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=rub' | jq -r '.tether.rub')

# Получаем курс TON к рублю
ton_rub=$(curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=the-open-network&vs_currencies=rub' | jq -r '.["the-open-network"].rub')

# Вывод данных для Polybar
echo "%{F#FFB86C}%{T8}%{T-}$btc_usd$ %{T-}%{F-}%{F#50FA7B}%{T2}󰇁%{T-}$usdt_rub%{T5}%{T-}%{F-} %{F#8BE9FD}%{T8}%{T-}$ton_rub%{T5}%{T-}%{F-}"

