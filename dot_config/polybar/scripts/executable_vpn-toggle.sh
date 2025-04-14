#!/bin/bash
# vpn-toggle.sh

# Конфигурация
CONFIG_FILE="/etc/openvpn/client.conf"
LOG_FILE="/var/log/openvpn.log"
LOCK_FILE="/tmp/vpn.lock"

# Инициализация логов
init_logs() {
    touch "$LOG_FILE" 2>/dev/null || touch "$LOG_FILE"
    chmod 666 "$LOG_FILE" 2>/dev/null || chmod 666 "$LOG_FILE"
}

# Логирование
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Основная логика
main() {
    init_logs
    log "Скрипт запущен"
    
    if pgrep -x openvpn >/dev/null; then
        log "Остановка VPN..."
        pkill -x openvpn
        sleep 2
        log "Статус: VPN остановлен"
    else
        log "Запуск VPN..."
        openvpn \
            --config "$CONFIG_FILE" \
            --daemon \
            --log "$LOG_FILE"
        sleep 3
        log "Статус: VPN запущен"
    fi
}

# Запуск
main
