#!/bin/bash
# tailscale-russia-fix.sh - Обход блокировки tailscale в России

echo "=== Tailscale Russia Fix ==="

# 1. Проверяем VPN
if ! systemctl is-active --quiet awg-quick@wg0.service; then
    echo "❌ VPN не активен! Запусти: awgq on"
    exit 1
fi

echo "✅ VPN активен"

# 2. Получаем VPN IP
VPN_IP=$(ip addr show wg0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
echo "VPN IP: $VPN_IP"

# 3. Проверяем доступность tailscale через VPN
echo "Проверяем tailscale через VPN..."
curl -s --interface wg0 -o /dev/null -w "%{http_code}" https://login.tailscale.com

# 4. Настраиваем tailscale чтобы использовать VPN интерфейс
# Создаём systemd drop-in для tailscaled
cat <<EOF | sudo tee /etc/systemd/system/tailscaled.service.d/vpn-fix.conf
[Service]
# Заставляем tailscaled использовать VPN для исходящих соединений
Environment="TS_DEBUG_MTU=1280"
Environment="TS_BIND_WG_PORT=0"
EOF

# 5. Добавляем маршрут для tailscale coordination server через VPN
# Получаем IP login.tailscale.com
TS_IP=$(dig +short login.tailscale.com | head -1)
if [ -n "$TS_IP" ]; then
    echo "Tailscale server IP: $TS_IP"
    sudo ip route add $TS_IP dev wg0 2>/dev/null || true
fi

# 6. Перезапускаем tailscaled
sudo systemctl daemon-reload
sudo systemctl restart tailscaled
sleep 3

# 7. Проверяем статус
echo ""
echo "=== Проверка ==="
tailscale status
ip addr show tailscale0

echo ""
echo "Если tailscale0 всё ещё без IP — попробуй:"
echo "  sudo tailscale up --reset --accept-dns=false"
echo ""
echo "Если не работает — используй прямой SSH через VPN:"
echo "  ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' mflkee@100.80.114.18"
