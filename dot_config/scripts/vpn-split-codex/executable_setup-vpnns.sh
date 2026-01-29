#!/usr/bin/env bash
set -euo pipefail

# путь к конфигу в твоих dotfiles (ПОПРАВЬ если у тебя иначе)
SRC_CONF="$HOME/.config/scripts/vpn-split-codex/nl.conf"

DST_DIR="/etc/amneziawg"
DST_CONF="$DST_DIR/nl.conf"

VPNNS_UP="/usr/local/sbin/vpnns-up"
VPNNS_DOWN="/usr/local/sbin/vpnns-down"
UNIT_FILE="/etc/systemd/system/vpnns.service"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "❌ missing: $1"; exit 1; }; }

need_cmd sudo
need_cmd ip
need_cmd nft
need_cmd systemctl
need_cmd awg
need_cmd awg-quick
need_cmd curl

if [[ ! -f "$SRC_CONF" ]]; then
  echo "❌ Config not found: $SRC_CONF"
  echo "👉 Fix SRC_CONF in this script."
  exit 1
fi

echo "== install config =="
sudo install -d -m 700 "$DST_DIR"
sudo install -m 600 "$SRC_CONF" "$DST_CONF"

echo "== write vpnns-up =="
sudo tee "$VPNNS_UP" >/dev/null <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

NS="vpnns"
VETH_HOST="veth-vpn"
VETH_NS="veth-ns"

HOST_IP="10.200.200.1/24"
NS_IP="10.200.200.2/24"
SUBNET="10.200.200.0/24"

WG_CFG="/etc/amneziawg/nl.conf"

ip netns del "$NS" 2>/dev/null || true
ip link del "$VETH_HOST" 2>/dev/null || true

ip netns add "$NS"
ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
ip link set "$VETH_NS" netns "$NS"

ip addr add "$HOST_IP" dev "$VETH_HOST"
ip link set "$VETH_HOST" up

ip netns exec "$NS" ip link set lo up
ip netns exec "$NS" ip addr add "$NS_IP" dev "$VETH_NS"
ip netns exec "$NS" ip link set "$VETH_NS" up
ip netns exec "$NS" ip route replace default via 10.200.200.1

sysctl -w net.ipv4.ip_forward=1 >/dev/null

nft delete table inet nat 2>/dev/null || true
nft delete table inet filter 2>/dev/null || true

nft add table inet nat
nft 'add chain inet nat postrouting { type nat hook postrouting priority srcnat; policy accept; }'
nft add rule inet nat postrouting ip saddr $SUBNET masquerade

nft add table inet filter
nft 'add chain inet filter forward { type filter hook forward priority filter; policy accept; }'

EP_IP="$(awk -F'[ :]' '/Endpoint/ {print $3}' "$WG_CFG")"
ip netns exec "$NS" ip route replace "$EP_IP"/32 via 10.200.200.1 dev "$VETH_NS"

ip netns exec "$NS" awg-quick up "$WG_CFG"
echo "✅ vpnns started"
EOT
sudo chmod 755 "$VPNNS_UP"

echo "== write vpnns-down =="
sudo tee "$VPNNS_DOWN" >/dev/null <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

NS="vpnns"
WG_CFG="/etc/amneziawg/nl.conf"

ip netns exec "$NS" awg-quick down "$WG_CFG" 2>/dev/null || true
ip netns del "$NS" 2>/dev/null || true
ip link del veth-vpn 2>/dev/null || true

nft delete table inet nat 2>/dev/null || true
nft delete table inet filter 2>/dev/null || true

echo "🧹 vpnns stopped"
EOT
sudo chmod 755 "$VPNNS_DOWN"

echo "== write systemd unit =="
sudo tee "$UNIT_FILE" >/dev/null <<'EOT'
[Unit]
Description=VPN network namespace (AmneziaWG) for Codex / OpenAI
After=network-online.target nftables.service
Wants=network-online.target nftables.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/vpnns-up
ExecStop=/usr/local/sbin/vpnns-down
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOT

echo "== enable service =="
sudo systemctl daemon-reload
sudo systemctl enable --now vpnns.service

echo "== smoke test (VPN IP expected) =="
sudo ip netns exec vpnns curl -4 --max-time 10 https://api.ipify.org
echo
echo "✅ done"
