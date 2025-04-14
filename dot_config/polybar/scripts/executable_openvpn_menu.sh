#!/bin/bash

CONFIG_DIR="/etc/openvpn/configs"
CURRENT_LINK="/etc/openvpn/client.conf"

# Список конфигураций
CONFIGS=$(find "$CONFIG_DIR" -type f -name "*.ovpn" -exec basename {} \;)

# Показываем меню Rofi
SELECTED=$(echo "$CONFIGS" | rofi -dmenu -p "Выберите VPN файл:")

# Если что-то выбрано
if [ -n "$SELECTED" ]; then
    NEW_CONFIG="$CONFIG_DIR/$SELECTED"
    
    # Меняем симлинк
    sudo ln -sf "$NEW_CONFIG" "$CURRENT_LINK"
    notify-send "OpenVPN" "Выбран файл: $SELECTED"
else
    notify-send "OpenVPN" "Выбор отменен"
fi
