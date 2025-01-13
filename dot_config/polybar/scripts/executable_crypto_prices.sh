#!/bin/bash

# Получаем курс Bitcoin к доллару
btc_usd=$(curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd' | jq -r '.bitcoin.usd')

# Получаем курс USDT к рублю
usdt_rub=$(curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=rub' | jq -r '.tether.rub')

# Получаем курс TON к рублю
ton_rub=$(curl -s 'https://api.coingecko.com/api/v3/simple/price?ids=the-open-network&vs_currencies=rub' | jq -r '.["the-open-network"].rub')

# Вывод данных для Polybar
echo "%{F#B8860B}%{T8}%{T-}$btc_usd$ %{T-}%{F-}%{F#6B8E23}%{T2}󰇁%{T-}$usdt_rub%{T5}%{T-}%{F-} %{F#4682B4}%{T8}%{T-}$ton_rub%{T5}%{T-}%{F-}"

