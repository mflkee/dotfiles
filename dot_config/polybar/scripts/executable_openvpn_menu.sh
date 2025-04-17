#!/bin/bash

CONFIG_DIR="$HOME/.config/openvpn/configs/"
CURRENT_LINK="$HOME/.config/openvpn/client.conf"
VPN_NAME="OpenVPN Connection"

# Получаем список доступных .ovpn файлов
CONFIGS=$(find "$CONFIG_DIR" -type f -name "*.ovpn" -exec basename {} \;)
SELECTED=$(echo "$CONFIGS" | rofi -dmenu -p "Выберите VPN файл:")

if [ -n "$SELECTED" ]; then
    NEW_CONFIG="$CONFIG_DIR$SELECTED"
    BASE_NAME="${SELECTED%.ovpn}"  # Убираем расширение .ovpn
    
    # Удаляем старое подключение, если оно существует
    nmcli connection delete "$BASE_NAME" 2>/dev/null || true
    nmcli connection delete "$VPN_NAME" 2>/dev/null || true
    
    # Импортируем новый .ovpn файл
    if nmcli connection import type openvpn file "$NEW_CONFIG"; then
        # Переименовываем подключение в фиксированное имя
        if nmcli connection modify "$BASE_NAME" connection.id "$VPN_NAME"; then
            notify-send "OpenVPN" "Выбран файл: $SELECTED. Подключитесь через Polybar." -t 2000
        else
            notify-send "OpenVPN" "Ошибка при переименовании подключения." -t 2000
        fi
    else
        notify-send "OpenVPN" "Ошибка при импорте файла: $SELECTED" -t 2000
    fi
else
    notify-send "OpenVPN" "Выбор отменен" -t 2000
fi
