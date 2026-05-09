#!/bin/bash
# tailscale-iptables-fix.sh - Исправление маршрутизации через iptables

echo "=== Tailscale IPTables Fix ==="

# 1. Очищаем старые правила
sudo iptables -t mangle -D PREROUTING -i tailscale0 -j MARK --set-mark 0x80000 2>/dev/null
sudo iptables -t mangle -D OUTPUT -o tailscale0 -j MARK --set-mark 0x80000 2>/dev/null

# 2. Добавляем маркировку для tailscale трафика
sudo iptables -t mangle -A PREROUTING -i tailscale0 -j MARK --set-mark 0x80000
sudo iptables -t mangle -A OUTPUT -o tailscale0 -j MARK --set-mark 0x80000

# 3. Добавляем ip rule для fwmark
sudo ip rule del pref 15 fwmark 0x80000/0xff0000 lookup main 2>/dev/null
sudo ip rule add pref 15 fwmark 0x80000/0xff0000 lookup main

# 4. Определяем приоритет AWG правила и вставляем Tailscale правило ВЫШЕ него
AWG_PRIORITY=$(ip rule show | grep -E "lookup 51820" | head -1 | cut -d: -f1 | tr -d ' ')
if [ -n "$AWG_PRIORITY" ]; then
    TAILSCALE_PRIORITY=$((AWG_PRIORITY - 1))
    if [ "$TAILSCALE_PRIORITY" -lt 0 ]; then
        TAILSCALE_PRIORITY=0
    fi
    echo "AWG rule at priority $AWG_PRIORITY, placing Tailscale rule at priority $TAILSCALE_PRIORITY"
else
    TAILSCALE_PRIORITY=10
    echo "AWG rule not found, using default priority 10"
fi

# Удаляем старые tailnet правила на всякий случай
for pref in 5 10 15 20 25 30 35 40 45 50 55 70 80 90 100; do
    sudo ip rule del pref "$pref" to 100.64.0.0/10 lookup 52 2>/dev/null
done

sudo ip rule del pref "$TAILSCALE_PRIORITY" to 100.64.0.0/10 lookup 52 2>/dev/null
sudo ip rule add pref "$TAILSCALE_PRIORITY" to 100.64.0.0/10 lookup 52

# Сбрасываем кэш маршрутов
sudo ip route flush cache

echo "=== Checking route ==="
ip route get 100.80.114.18

echo "=== Done ==="
