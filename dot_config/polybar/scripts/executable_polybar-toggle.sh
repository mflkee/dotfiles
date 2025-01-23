#!/usr/bin/env bash

# Конфигурация
BAR_NAME="DisB"
POLYBAR_HEIGHT=25
CONFIG="$HOME/.config/polybar/config.ini"
LOCK_FILE="/tmp/polybar.lock"
LOG_FILE="/tmp/polybar.log"

# Инициализация лога
exec 2>"$LOG_FILE"

# Проверка зависимостей
check_dependencies() {
    command -v polybar >/dev/null || { echo "Polybar не установлен"; exit 1; }
    command -v bspc >/dev/null || { echo "Bspwm не установлен"; exit 1; }
}

# Основная функция
toggle_polybar() {
    if [ -f "$LOCK_FILE" ]; then
        # Показать панель
        start_polybar
        rm -f "$LOCK_FILE"
    else
        # Скрыть панель
        stop_polybar
        touch "$LOCK_FILE"
    fi
}

start_polybar() {
    echo "Запуск Polybar..."
    killall -q polybar
    while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
    
    # Запуск через основной скрипт
    "$HOME/.config/polybar/launch.sh"
    
    sleep 0.5
    bspc config top_padding $POLYBAR_HEIGHT
}

stop_polybar() {
    echo "Остановка Polybar..."
    polybar-msg -p $(pgrep -f "polybar $BAR_NAME") cmd quit
    bspc config top_padding 0
}

# Главный цикл
main() {
    check_dependencies
    toggle_polybar
    bspc node @/ -R 0,0,-0,-0  # Обновить окна
}

main
