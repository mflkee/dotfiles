#!/bin/bash

# Получаем текущую раскладку через xkb-switch
current_layout=$(xkb-switch)

# Определяем отображение на основе раскладки
if [ "$current_layout" == "us" ]; then
  lang="%{F#80a0ff}US"
else
  lang="%{F#ff5454}RU"
fi

# Используем %{T2} для указания шрифта font-2
output="%{T2}${lang}%{T}"

# Выводим результат
echo "$output"
