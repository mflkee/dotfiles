#!/bin/bash

DOWNLOAD_DIR=~/downloads
OBSIDIAN_DIR="/home/mflkee/obsidian/13. math/cache/"

# Проверка существования папки
if [ ! -d "$OBSIDIAN_DIR" ]; then
    echo "Папка $OBSIDIAN_DIR не существует!"
    exit 1
fi

echo "Отслеживание изменений в папке $DOWNLOAD_DIR..."

# Отслеживаем изменения в папке загрузок
inotifywait -m -e close_write "$DOWNLOAD_DIR" --format '%w%f' | while read FILE
do
    echo "Обнаружен файл: $FILE"
    
    # Получаем имя файла и его расширение
    FILENAME=$(basename "$FILE")
    FILE_EXTENSION="${FILENAME##*.}"

    # Определяем источник файла по имени или URL
    if [[ "$FILENAME" == *"diagram"* && "$FILE_EXTENSION" == "png" ]]; then
        echo "Обрабатывается файл: $FILENAME"
        sleep 5
        mv "$FILE" "$OBSIDIAN_DIR/"
        echo "Перемещен $FILENAME в $OBSIDIAN_DIR"
    else
        echo "Файл не соответствует критериям: $FILENAME"
    fi
done
