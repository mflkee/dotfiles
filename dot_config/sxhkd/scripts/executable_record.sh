#!/bin/bash

# Путь для сохранения видеофайла
OUTPUT_PATH="/home/$USER/videos/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"

# Размер экрана (автоматически определяется, можно изменить вручную, например, на "1920x1080")
SCREEN_SIZE=$(xdpyinfo | grep 'dimensions:' | awk '{print $2}' | tr -d ',')

# FPS (кадров в секунду) для записи
FPS="60"

# Идентификатор устройства захвата аудио (получить список устройств: `pacmd list-sources | grep 'name:'`)
AUDIO_DEVICE="alsa_input.pci-0000_00_1f.3.analog-stereo"

# Запуск записи
echo "Запись экрана начата. Чтобы остановить, нажмите Ctrl+C в этом терминале."
ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :1.0+0,0 -f pulse -i $AUDIO_DEVICE -c:v libx264 -crf 18 -c:a aac -b:a 128k $OUTPUT_PATH

echo "Запись экрана остановлена. Видеофайл сохранён как: $OUTPUT_PATH"
