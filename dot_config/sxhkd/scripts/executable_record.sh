#!/bin/bash

# Настройки окружения
export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"
xhost +local: >/dev/null 2>&1

# Пути и файлы
OUTPUT_DIR="$HOME/videos"
mkdir -p "$OUTPUT_DIR"
LOCK_FILE="/tmp/screen_record.pid"
LOG_FILE="$OUTPUT_DIR/ffmpeg.log"

# Функция для остановки записи
stop_recording() {
    if [ -f "$LOCK_FILE" ]; then
        PID=$(cat "$LOCK_FILE")
        if ps -p "$PID" > /dev/null; then
            # Отправляем SIGINT для корректного завершения ffmpeg
            kill -INT "$PID"
            # Ждем завершения процесса
            for i in {1..10}; do
                if ! ps -p "$PID" > /dev/null; then
                    break
                fi
                sleep 1
            done
            # Если процесс все еще работает, принудительно завершаем
            if ps -p "$PID" > /dev/null; then
                kill -9 "$PID"
            fi
        fi
        rm -f "$LOCK_FILE"
        notify-send "Запись экрана" "Запись остановлена."
        return 0
    fi
    return 1
}

# Если запись уже идет, останавливаем
if stop_recording; then
    exit 0
fi

# Получение параметров экрана
SCREEN_INFO=$(xdpyinfo | grep -oP 'dimensions:\s+\K\S+')
if [ -z "$SCREEN_INFO" ]; then
    notify-send "Ошибка" "Не удалось определить параметры экрана."
    exit 1
fi

# Определение аудиоустройств
get_audio_devices() {
    MIC_DEVICE=$(pactl list sources short | grep -i 'input\|mic' | awk '{print $2}' | head -n1)
    DEFAULT_SINK=$(pactl get-default-sink)
    SYS_DEVICE="${DEFAULT_SINK}.monitor"
    echo "$MIC_DEVICE $SYS_DEVICE"
}

# Получаем устройства
read MIC_DEVICE SYS_DEVICE <<< $(get_audio_devices)

# Выбор качества
QUALITY=$(echo -e "1. Высокое (60 FPS, CRF 18)\n2. Среднее (30 FPS, CRF 23)\n3. Низкое (30 FPS, CRF 28)" | rofi -dmenu -p "Выберите качество:")
case "$QUALITY" in
    "1. Высокое (60 FPS, CRF 18)") FPS=60; CRF=18; AUDIO_BITRATE="256k" ;;
    "2. Среднее (30 FPS, CRF 23)") FPS=30; CRF=23; AUDIO_BITRATE="192k" ;;
    "3. Низкое (30 FPS, CRF 28)") FPS=30; CRF=28; AUDIO_BITRATE="128k" ;;
    *) exit 1 ;;
esac

# Включить микрофон?
MIC_CHOICE=$(echo -e "Да\nНет" | rofi -dmenu -p "Включить микрофон?")
USE_MIC=$([ "$MIC_CHOICE" = "Да" ] && [ -n "$MIC_DEVICE" ] && echo true || echo false)

# Включить системный звук?
SYS_CHOICE=$(echo -e "Да\nНет" | rofi -dmenu -p "Включить системный звук?")
USE_SYS=$([ "$SYS_CHOICE" = "Да" ] && [ -n "$SYS_DEVICE" ] && echo true || echo false)

# Формирование команды FFmpeg
FFMPEG_CMD=(ffmpeg -y -loglevel error -video_size "$SCREEN_INFO" -framerate "$FPS" -f x11grab -i "$DISPLAY")

# Добавляем аудио источники
AUDIO_SOURCES=()
if $USE_MIC; then
    FFMPEG_CMD+=(-f pulse -i "$MIC_DEVICE")
    AUDIO_SOURCES+=("1:a")
fi

if $USE_SYS; then
    FFMPEG_CMD+=(-f pulse -i "$SYS_DEVICE")
    AUDIO_SOURCES+=("2:a")
fi

# Обрабатываем аудио
if [ ${#AUDIO_SOURCES[@]} -gt 0 ]; then
    if [ ${#AUDIO_SOURCES[@]} -eq 2 ]; then
        FFMPEG_CMD+=(-filter_complex "[1:a][2:a]amerge=inputs=2[a]" -map 0:v -map "[a]")
    else
        FFMPEG_CMD+=(-map 0:v -map "${AUDIO_SOURCES[0]}")
    fi
    FFMPEG_CMD+=(-c:a aac -b:a "$AUDIO_BITRATE")
else
    FFMPEG_CMD+=(-an)
fi

# Завершаем формирование команды
OUTPUT_PATH="$OUTPUT_DIR/screen_$(date +%Y%m%d_%H%M%S).mp4"
FFMPEG_CMD+=(-c:v libx264 -preset fast -crf "$CRF" -pix_fmt yuv420p "$OUTPUT_PATH")

# Запуск записи
"${FFMPEG_CMD[@]}" > "$LOG_FILE" 2>&1 &
PID=$!

# Сохранение PID
echo $PID > "$LOCK_FILE"
notify-send "Запись экрана" "Запись начата. Видео будет сохранено в:\n$OUTPUT_PATH"

# Проверка запуска
sleep 2
if ! ps -p "$PID" > /dev/null; then
    notify-send "Ошибка" "Не удалось начать запись. Проверьте логи:\n$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi
