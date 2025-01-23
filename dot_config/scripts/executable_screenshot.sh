#!/bin/bash

# Папка для сохранения скриншотов
screenshot_dir="$HOME/screenshots"
mkdir -p "$screenshot_dir"

# Имя файла скриншота
screenshot_file="$screenshot_dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).jpg"

# Использование rofi для выбора действия
action=$(echo -e "1. Скриншот всего экрана\n2. Скриншот текущего окна\n3. Скриншот выделенной области" | rofi -dmenu -p "Выберите действие:" -theme-str 'window {location: center;}')

# Обработка выбранного действия
case "$action" in
    "1. Скриншот всего экрана")
        scrot "$screenshot_file"
        ;;
    "2. Скриншот текущего окна")
        scrot -u "$screenshot_file"
        ;;
    "3. Скриншот выделенной области")
        scrot -s "$screenshot_file"
        ;;
    *)
        echo "Неверный выбор. Выход."
        exit 1
        ;;
esac

# Копирование скриншота в буфер обмена
xclip -selection clipboard -t image/jpg -i "$screenshot_file"

# Сообщение об успешной операции
notify-send "Скриншот" "Скриншот сохранен и скопирован в буфер обмена."
