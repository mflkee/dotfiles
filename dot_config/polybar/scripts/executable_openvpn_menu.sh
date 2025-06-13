#!/bin/bash

CONFIG_DIR="$HOME/.config/openvpn/configs/"
VPN_NAME="OpenVPN Connection"

# Получаем список доступных .ovpn файлов
CONFIGS=$(find "$CONFIG_DIR" -type f -name "*.ovpn" -exec basename {} \;)
SELECTED=$(echo "$CONFIGS" | rofi -dmenu -p "Выберите VPN файл:")

if [ -n "$SELECTED" ]; then
    NEW_CONFIG="$CONFIG_DIR$SELECTED"
    BASE_NAME="${SELECTED%.ovpn}"

    # Удаляем старое подключение
    nmcli connection delete "$BASE_NAME" 2>/dev/null || true
    nmcli connection delete "$VPN_NAME" 2>/dev/null || true

    # Импортируем новый .ovpn файл
    if nmcli connection import type openvpn file "$NEW_CONFIG"; then
        nmcli connection modify "$BASE_NAME" connection.id "$VPN_NAME"
        notify-send "OpenVPN" "Файл $SELECTED загружен. Подключайтесь." -t 2000
    else
        notify-send "OpenVPN" "Ошибка импорта файла $SELECTED" -t 2000
    fi
else
    notify-send "OpenVPN" "Выбор отменён" -t 2000
fi
