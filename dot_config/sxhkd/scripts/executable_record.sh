#!/bin/bash

# Путь для сохранения видеофайла
OUTPUT_PATH="/home/$USER/videos/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"

# Размер экрана
SCREEN_SIZE=$(xdpyinfo | grep 'dimensions:' | awk '{print $2}' | tr -d ',')
if [ -z "$SCREEN_SIZE" ]; then
  echo "Ошибка: не удалось определить размер экрана."
  exit 1
fi

# FPS (кадров в секунду) для записи
FPS="30"

# Идентификатор устройства захвата аудио (используем pactl для PipeWire)
AUDIO_DEVICE=$(pactl list sources | grep -E 'Name:|Description:' | awk '/Name:/ {device=$2} /Description:/ {print device, $0}' | grep "Mic1" | awk '{print $1}')
if [ -z "$AUDIO_DEVICE" ]; then
  echo "Ошибка: устройство захвата аудио не найдено."
  exit 1
fi

# Создание каталога для сохранения видео
mkdir -p /home/$USER/videos

# Файл-маркер для отслеживания состояния записи
LOCK_FILE="/tmp/screen_record.lock"

# Если запись уже запущена, завершаем её
if [ -f "$LOCK_FILE" ]; then
  PID=$(cat "$LOCK_FILE")
  kill -TERM "$PID" 2>/dev/null
  rm "$LOCK_FILE"
  notify-send "Запись экрана" "Запись остановлена. Видео сохранено в $OUTPUT_PATH."
  exit 0
fi

# Запуск записи
echo "Запись экрана начата. Чтобы остановить, нажмите горячие клавиши ещё раз."
ffmpeg -video_size $SCREEN_SIZE -framerate $FPS -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $AUDIO_DEVICE -c:v libx264 -crf 18 -c:a aac -b:a 128k "$OUTPUT_PATH" &
echo $! > "$LOCK_FILE"
notify-send "Запись экрана" "Запись начата."
