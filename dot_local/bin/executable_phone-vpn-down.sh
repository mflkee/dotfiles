#!/bin/bash
# Откат туннеля: убрать tun0, вернуть IPv6 на wlo1
# Вызывается из /etc/NetworkManager/dispatcher.d/90-phone-vpn
# Запускать: sudo ./phone-vpn-down.sh
set -e

TUN=tun0
PROXY_IF=wlo1

echo "==> Останавливаю tun2socks"
pkill -f "tun2socks -device $TUN" 2>/dev/null || true

echo "==> Удаляю маршрут через tun0"
ip route del default dev $TUN 2>/dev/null || true

echo "==> Удаляю интерфейс $TUN"
ip link set $TUN down 2>/dev/null || true
ip tuntap del mode tun dev $TUN 2>/dev/null || true

echo "==> Возвращаю IPv6 на $PROXY_IF (если сеть его поддерживает)"
sysctl -w net.ipv6.conf.$PROXY_IF.disable_ipv6=0 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1 || true

echo "==> Маршруты:"
ip route | grep default || echo "(дефолтный маршрут восстановит DHCP-клиент)"
