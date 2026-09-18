#!/bin/bash
# Настройка прозрачного туннеля через SOCKS5 телефона (Happ) + tun2socks
# Вызывается из /etc/NetworkManager/dispatcher.d/90-phone-vpn
# Запускать: sudo ./phone-vpn-up.sh
set -e

PROXY="192.168.43.1:10808"
TUN=tun0
TUN_IP="10.0.0.1"
BIN="/home/mflkee/.local/bin/tun2socks"
PROXY_IF=wlo1
LOG=/tmp/opencode/tun2socks.log

echo "==> Отключаю IPv6 на $PROXY_IF (канал телефона IPv4-only)"
sysctl -w net.ipv6.conf.$PROXY_IF.disable_ipv6=1 >/dev/null 2>&1 || true
ip -6 addr flush dev $PROXY_IF 2>/dev/null || true
ip -6 route flush dev $PROXY_IF 2>/dev/null || true

echo "==> Создаю TUN-интерфейс $TUN"
ip tuntap del mode tun dev $TUN 2>/dev/null || true
ip tuntap add mode tun dev $TUN
ip addr flush dev $TUN 2>/dev/null || true
ip addr add $TUN_IP/24 dev $TUN
ip link set $TUN up

echo "==> Дефолтный маршрут через $TUN (metric 100; локальная сеть телефона напрямую)"
ip route del default dev $TUN 2>/dev/null || true
ip route add default dev $TUN metric 100

# Исключения из туннеля: WebDAV NAS (webdav.mkair.ru) через прокси телефона
# не проходит, поэтому ведём его напрямую через $PROXY_IF.
GW="${PROXY%%:*}"
for ip in $(getent ahostsv4 webdav.mkair.ru 2>/dev/null | awk '{print $1}' | sort -u); do
    echo "==> Обход туннеля для NAS: $ip via $GW dev $PROXY_IF"
    ip route replace "$ip" via "$GW" dev "$PROXY_IF" metric 50 2>/dev/null || true
done

echo "==> Запускаю tun2socks (лог $LOG)"
pkill -f "tun2socks -device $TUN" 2>/dev/null || true
sleep 0.5
nohup "$BIN" -device $TUN -proxy socks5://$PROXY -loglevel info > "$LOG" 2>&1 &
sleep 1

echo "==> Состояние:"
ip route | grep -E "default|$TUN"
echo "tun2socks pid: $(pgrep -f 'tun2socks -device' || echo 'НЕ ЗАПУЩЕН')"
