#!/bin/bash

# Получаем текущий расклад клавиатуры
layout=$(xset -q | grep -A 0 'LED' | awk '{ print $10 }')

# Определяем активный расклад на основе светодиодного состояния клавиатуры
if [ "$layout" -eq 00000000 ]; then
  lang="US"
  color="%{F#0000FF}"
else
  lang="RU"
  color="%{F#FF0000}"
fi

# Используем %{T3}% для указания шрифта font-2 из вашей конфигурации polybar
output="%{T2}${color}${lang}%{T}%{F-}"  # %{F-} сбрасывает цвет обратно на цвет по умолчанию

echo "$output"
