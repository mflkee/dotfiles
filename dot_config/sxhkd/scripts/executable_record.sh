#!/bin/bash

# Путь для сохранения видеофайла
OUTPUT_DIR="/home/$USER/videos"
mkdir -p "$OUTPUT_DIR"

# Файл-маркер для отслеживания состояния записи
LOCK_FILE="/tmp/screen_record.lock"

# Если запись уже запущена, завершаем её
if [ -f "$LOCK_FILE" ]; then
  PID=$(cat "$LOCK_FILE")
  kill -INT "$PID" 2>/dev/null
  rm "$LOCK_FILE"
  notify-send "Запись экрана" "Запись остановлена."
  exit 0
fi

# Размер экрана
SCREEN_SIZE=$(xdpyinfo | rg 'dimensions:' | awk '{print $2}' | tr -d ',')
if [ -z "$SCREEN_SIZE" ]; then
  echo "Ошибка: не удалось определить размер экрана."
  exit 1
fi

# Идентификатор устройства захвата микрофона
MIC_DEVICE=$(pactl list sources | rg 'Name:|Description:' | awk '/Name:/ {device=$2} /Description:/ {print device, $0}' | rg "Mic1" | awk '{print $1}')
if [ -z "$MIC_DEVICE" ]; then
  echo "Ошибка: устройство захвата микрофона не найдено."
  exit 1
fi

# Идентификатор устройства захвата системного звука
SYS_DEVICE=$(pactl get-default-sink).monitor
if [ -z "$SYS_DEVICE" ]; then
    echo "Ошибка: устройство захвата системного звука не найдено."
    exit 1
fi

PRESET=$(echo -e "1. MP4 (30 FPS, среднее качество)\n2. MP4 (60 FPS, высокое качество)\n3. Запись без звука\n4. Запись с микрофоном и системным звуком\n5. Запись только с системным звуком\n6. Запись только с микрофоном" | rofi -dmenu -p "Выберите предустановку:")

case "$PRESET" in
  "1. MP4 (30 FPS, среднее качество)")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "2. MP4 (60 FPS, высокое качество)")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 60 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -c:v libx264 -crf 18 -c:a aac -b:a 192k "$OUTPUT_PATH" &
    ;;
  "3. Запись без звука")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -c:v libx264 -crf 23 "$OUTPUT_PATH" &
    ;;
  "4. Запись с микрофоном и системным звуком")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -f pulse -i $SYS_DEVICE -filter_complex "[1:a][2:a]amerge=inputs=2[a]" -map 0:v -map "[a]" -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "5. Запись только с системным звуком")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $SYS_DEVICE -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "6. Запись только с микрофоном")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  *)
    echo "Предустановка не выбрана. Выход."
    exit 1
    ;;
esac

# Сохраняем PID процесса записи
echo $! > "$LOCK_FILE"
notify-send "Запись экрана" "Запись начата. Видео будет сохранено в $OUTPUT_PATH."
