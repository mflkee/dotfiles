#!/bin/bash
# split-mode-fix.sh - Исправление split mode через iptables

echo "=== Split Mode Fix ==="

# 1. Очищаем старые правила iptables
sudo iptables -t mangle -F PREROUTING 2>/dev/null
sudo iptables -t mangle -F OUTPUT 2>/dev/null

# 2. Получаем IP VPN-доменов и маркируем их
VPN_IPS=(
    $(dig +short telegram.org | head -1)
    $(dig +short youtube.com | head -1)
    $(dig +short instagram.com | head -1)
)

echo "VPN IPs: ${VPN_IPS[@]}"

# 3. Маркируем пакеты к VPN IP с fwmark 0xca6c (чтобы AWG не перехватил)
for ip in "${VPN_IPS[@]}"; do
    if [ -n "$ip" ]; then
        sudo iptables -t mangle -A PREROUTING -d $ip -j MARK --set-mark 0xca6c
        sudo iptables -t mangle -A OUTPUT -d $ip -j MARK --set-mark 0xca6c
        echo "Marked $ip with fwmark 0xca6c"
    fi
done

# 4. Добавляем маршруты для VPN IP через wg0 в таблицу main
for ip in "${VPN_IPS[@]}"; do
    if [ -n "$ip" ]; then
        sudo ip route del $ip 2>/dev/null
        sudo ip route add $ip dev wg0
        echo "Route added: $ip via wg0"
    fi
done

# 5. Проверяем
echo ""
echo "=== Checking routes ==="
for ip in "${VPN_IPS[@]}"; do
    if [ -n "$ip" ]; then
        echo -n "$ip: "
        ip route get $ip 2>/dev/null | head -1
    fi
done

echo ""
echo "=== Done ==="
