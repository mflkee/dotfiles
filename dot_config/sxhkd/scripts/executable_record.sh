#!/bin/bash

# Путь для сохранения видеофайла
OUTPUT_DIR="/home/$USER/videos"
mkdir -p "$OUTPUT_DIR"

# Файл-маркер для отслеживания состояния записи
LOCK_FILE="/tmp/screen_record.lock"

# Если запись уже запущена, завершаем её
if [ -f "$LOCK_FILE" ]; then
  PID=$(cat "$LOCK_FILE")
  kill -TERM "$PID" 2>/dev/null
  rm "$LOCK_FILE"
  notify-send "Запись экрана" "Запись остановлена."
  exit 0
fi

# Размер экрана
SCREEN_SIZE=$(xdpyinfo | grep 'dimensions:' | awk '{print $2}' | tr -d ',')
if [ -z "$SCREEN_SIZE" ]; then
  echo "Ошибка: не удалось определить размер экрана."
  exit 1
fi

# Идентификатор устройства захвата микрофона
MIC_DEVICE=$(pactl list sources | grep -E 'Name:|Description:' | awk '/Name:/ {device=$2} /Description:/ {print device, $0}' | grep "Mic1" | awk '{print $1}')
if [ -z "$MIC_DEVICE" ]; then
  echo "Ошибка: устройство захвата микрофона не найдено."
  exit 1
fi

# Идентификатор устройства захвата системного звука
SYS_DEVICE=$(pactl list sources | grep -E 'Name:|Description:' | awk '/Name:/ {device=$2} /Description:/ {print device, $0}' | grep "Monitor" | awk '{print $1}')
if [ -z "$SYS_DEVICE" ]; then
  echo "Ошибка: устройство захвата системного звука не найдено."
  exit 1
fi

# Выбор предустановки через rofi
PRESET=$(echo -e "1. MP4 (30 FPS, среднее качество)\n2. MP4 (60 FPS, высокое качество)\n3. GIF (низкое качество, малый размер)\n4. Запись без звука\n5. Запись области экрана\n6. Запись с микрофоном и системным звуком\n7. Запись только с системным звуком\n8. Запись только с микрофоном" | rofi -dmenu -p "Выберите предустановку:")

case "$PRESET" in
  "1. MP4 (30 FPS, среднее качество)")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "2. MP4 (60 FPS, высокое качество)")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 60 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -c:v libx264 -crf 18 -c:a aac -b:a 192k "$OUTPUT_PATH" &
    ;;
  "3. GIF (низкое качество, малый размер)")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).gif"
    ffmpeg -video_size $SCREEN_SIZE -framerate 15 -draw_mouse 0 -f x11grab -i :0.0+0,0 -vf "scale=640:-1,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" "$OUTPUT_PATH" &
    ;;
  "4. Запись без звука")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -c:v libx264 -crf 23 "$OUTPUT_PATH" &
    ;;
  "5. Запись области экрана")
    AREA=$(slop -f "%x %y %w %h")  # Используем slop для выбора области
    if [ -z "$AREA" ]; then
      echo "Ошибка: область не выбрана."
      exit 1
    fi
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $(echo $AREA | awk '{print $3"x"$4}') -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+$(echo $AREA | awk '{print $1","$2}') -f pulse -i $MIC_DEVICE -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "6. Запись с микрофоном и системным звуком")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $MIC_DEVICE -f pulse -i $SYS_DEVICE -filter_complex "[1:a][2:a]amerge=inputs=2[a]" -map 0:v -map "[a]" -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "7. Запись только с системным звуком")
    OUTPUT_PATH="$OUTPUT_DIR/screen_record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ffmpeg -video_size $SCREEN_SIZE -framerate 30 -draw_mouse 0 -f x11grab -i :0.0+0,0 -f pulse -i $SYS_DEVICE -c:v libx264 -crf 23 -c:a aac -b:a 128k "$OUTPUT_PATH" &
    ;;
  "8. Запись только с микрофоном")
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
