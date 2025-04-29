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

# Проверка установки FFmpeg
if ! command -v ffmpeg &> /dev/null; then
    notify-send "Ошибка" "FFmpeg не установлен!"
    exit 1
fi

# Функция для остановки записи
stop_recording() {
    if [ -f "$LOCK_FILE" ]; then
        PID=$(cat "$LOCK_FILE")
        if ps -p "$PID" > /dev/null; then
            kill -INT "$PID"
            for i in {1..10}; do
                ps -p "$PID" > /dev/null || break
                sleep 1
            done
            ps -p "$PID" > /dev/null && kill -9 "$PID"
        fi
        rm -f "$LOCK_FILE"
        notify-send "Запись экрана" "Запись остановлена."
        return 0
    fi
    return 1
}

# Остановка существующей записи
if stop_recording; then
    exit 0
fi

# Получение информации об экранах
get_screens() {
    xrandr --listactivemonitors | awk 'NR>1 {
        gsub(/\/[0-9]+/, "", $3)
        print $4 " " $3
    }'
}

mapfile -t SCREENS < <(get_screens)

if [ ${#SCREENS[@]} -eq 0 ]; then
    notify-send "Ошибка" "Не найдены активные экраны"
    exit 1
fi

# Выбор экрана
SELECTED_SCREEN=""
if [ ${#SCREENS[@]} -gt 1 ]; then
    SCREEN_CHOICES=()
    for screen in "${SCREENS[@]}"; do
        IFS=' ' read -r name geometry <<< "$screen"
        SCREEN_CHOICES+=("$name ($geometry)")
    done
    SELECTED=$(printf "%s\n" "${SCREEN_CHOICES[@]}" | rofi -dmenu -p "Выберите экран")
    [[ -z "$SELECTED" ]] && exit 0
    
    for screen in "${SCREENS[@]}"; do
        if [[ "$screen" == *"${SELECTED%% *}"* ]]; then
            SELECTED_SCREEN=$screen
            break
        fi
    done
else
    SELECTED_SCREEN=${SCREENS[0]}
fi

# Парсинг параметров экрана
IFS=' ' read -r SCREEN_NAME SCREEN_GEOM <<< "$SELECTED_SCREEN"
SCREEN_SIZE="${SCREEN_GEOM%%+*}"
SCREEN_OFFSET="${SCREEN_GEOM#*+}"

# Проверка параметров экрана
if [[ -z "$SCREEN_SIZE" || ! "$SCREEN_SIZE" =~ ^[0-9]+x[0-9]+$ || -z "$SCREEN_OFFSET" ]]; then
    notify-send "Ошибка" "Некорректные параметры экрана: ${SCREEN_SIZE}x${SCREEN_OFFSET}"
    exit 1
fi

# Логирование параметров
echo "Выбран экран: $SELECTED_SCREEN" >> "$LOG_FILE"
echo "Размер: $SCREEN_SIZE, Смещение: $SCREEN_OFFSET" >> "$LOG_FILE"

# Получение аудиоустройств
MIC_DEVICE=$(pactl get-default-source)
DEFAULT_SINK=$(pactl get-default-sink)
SYS_DEVICE="${DEFAULT_SINK}.monitor"

# Выбор качества
QUALITY=$(echo -e "1. Высокое (60 FPS, CRF 18)\n2. Среднее (30 FPS, CRF 23)\n3. Низкое (30 FPS, CRF 28)" | rofi -dmenu -p "Выберите качество:")
case "$QUALITY" in
    "1. Высокое"*) FPS=60; CRF=18; AUDIO_BITRATE="256k" ;;
    "2. Среднее"*) FPS=30; CRF=23; AUDIO_BITRATE="192k" ;;
    "3. Низкое"*) FPS=30; CRF=28; AUDIO_BITRATE="128k" ;;
    *) exit 1 ;;
esac

# Настройки аудио
MIC_CHOICE=$(echo -e "Да\nНет" | rofi -dmenu -p "Включить микрофон?")
USE_MIC=$([ "$MIC_CHOICE" = "Да" ] && [ -n "$MIC_DEVICE" ] && echo true || echo false)

SYS_CHOICE=$(echo -e "Да\nНет" | rofi -dmenu -p "Включить системный звук?")
USE_SYS=$([ "$SYS_CHOICE" = "Да" ] && [ -n "$SYS_DEVICE" ] && echo true || echo false)

# Проверка аудиоустройств
if $USE_MIC && [ -z "$MIC_DEVICE" ]; then
    notify-send "Ошибка" "Микрофон не найден!"
    exit 1
fi

if $USE_SYS && [ -z "$SYS_DEVICE" ]; then
    notify-send "Ошибка" "Системное аудио не найдено!"
    exit 1
fi

# Формирование команды FFmpeg
FFMPEG_CMD=(
    ffmpeg -y
    -loglevel error
    -video_size "$SCREEN_SIZE"
    -framerate "$FPS"
    -f x11grab
    -i "$DISPLAY+$SCREEN_OFFSET"
)

# Добавление аудиоисточников
AUDIO_SOURCES=()
if $USE_MIC; then
    FFMPEG_CMD+=(-f pulse -i "$MIC_DEVICE")
    AUDIO_SOURCES+=("1:a")
fi

if $USE_SYS; then
    FFMPEG_CMD+=(-f pulse -i "$SYS_DEVICE")
    AUDIO_SOURCES+=("2:a")
fi

# Микширование аудио
if [ ${#AUDIO_SOURCES[@]} -gt 0 ]; then
    if [ ${#AUDIO_SOURCES[@]} -eq 2 ]; then
        FFMPEG_CMD+=(
            -filter_complex "
            [1:a]aformat=channel_layouts=stereo[mic];
            [2:a]aformat=channel_layouts=stereo[sys];
            [mic][sys]amix=inputs=2:duration=longest[a]"
            -map 0:v -map "[a]"
        )
    else
        FFMPEG_CMD+=(-map 0:v -map "${AUDIO_SOURCES[0]}")
    fi
    FFMPEG_CMD+=(-c:a libopus -b:a "$AUDIO_BITRATE" -vbr on)
else
    FFMPEG_CMD+=(-an)
fi

# Параметры видео
FFMPEG_CMD+=(
    -c:v libx264
    -preset fast
    -crf "$CRF"
    -pix_fmt yuv420p
    -tune zerolatency
    -threads 4
    "$OUTPUT_DIR/screen_$(date +%Y%m%d_%H%M%S).mp4"
)

# Запуск записи
"${FFMPEG_CMD[@]}" > "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$LOCK_FILE"

# Проверка запуска
sleep 2
if ! ps -p "$PID" > /dev/null; then
    notify-send "Ошибка" "Не удалось начать запись. Проверьте логи:\n$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

notify-send "Запись экрана" "Запись начата на экране $SCREEN_NAME"
