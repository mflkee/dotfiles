#!/bin/bash

# Папка для сохранения скриншотов
screenshot_dir="$HOME/screenshots"
mkdir -p "$screenshot_dir"

# Имя файла скриншота
screenshot_file="$screenshot_dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Использование rofi для выбора действия
action=$(echo -e "1. Скриншот всего экрана\n2. Скриншот текущего окна\n3. Скриншот выделенной области" | rofi -dmenu -p "Выберите действие:" -theme-str 'window {location: center;}')

# Отмена выбора в rofi
if [[ -z "$action" ]]; then
    command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Отменено"
    exit 0
fi

# Задержка для закрытия rofi перед скриншотом
sleep 0.3

# Обработка выбранного действия
case "$action" in
    "1. Скриншот всего экрана")
        maim --hidecursor "$screenshot_file"
        ;;
    "2. Скриншот текущего окна")
        maim --hidecursor -i "$(xdotool getactivewindow)" "$screenshot_file"
        ;;
    "3. Скриншот выделенной области")
        maim --hidecursor -s "$screenshot_file"
        ;;
    *)
        command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Отменено"
        exit 0
        ;;
esac

# Если файл не создан (например, отмена выделения) — уведомить и выйти
if [[ ! -s "$screenshot_file" ]]; then
    command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Отменено"
    exit 0
fi

# Копирование скриншота в буфер обмена
xclip -selection clipboard -t image/png -i "$screenshot_file" 2>/dev/null || true

# Сообщение об успешной операции
command -v notify-send >/dev/null 2>&1 && notify-send "Скриншот" "Скриншот сохранен и скопирован в буфер обмена."
