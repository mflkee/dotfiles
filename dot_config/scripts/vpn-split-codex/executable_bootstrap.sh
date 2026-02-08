#!/usr/bin/env bash
set -euo pipefail

# === где лежит конфиг в твоих dotfiles (в рабочей системе, после chezmoi apply) ===
SRC_CONF="${SRC_CONF:-$HOME/.config/amneziawg/full/nl.conf}"

# === куда ставим в систему ===
DST_DIR="/etc/amneziawg"
DST_CONF="$DST_DIR/nl.conf"

VPNNS_UP="/usr/local/sbin/vpnns-up"
VPNNS_DOWN="/usr/local/sbin/vpnns-down"
UNIT_FILE="/etc/systemd/system/vpnns.service"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ missing: $1"; exit 1; }; }

echo "== check deps =="
for c in ip nft awg-quick systemctl awk cut; do need "$c"; done

echo "== check config =="
if [[ ! -f "$SRC_CONF" ]]; then
  echo "❌ Config not found: $SRC_CONF"
  echo "👉 Сначала: chezmoi apply (чтобы nl.conf появился локально)"
  exit 1
fi

echo "== install config to /etc =="
sudo install -d -m 700 "$DST_DIR"
sudo install -m 600 "$SRC_CONF" "$DST_CONF"

echo "== write vpnns-up (idempotent) =="
sudo tee "$VPNNS_UP" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

NS="vpnns"
VETH_HOST="veth-vpn"
VETH_NS="veth-ns"

HOST_IP="10.200.200.1/24"
NS_IP="10.200.200.2/24"

CFG="/etc/amneziawg/nl.conf"

# uplink (wlan0/eno1/etc)
UPLINK="$(ip route show default | awk '/default/ {print $5; exit}')"
[[ -n "$UPLINK" ]] || { echo "❌ no default route (uplink unknown)"; exit 1; }

# clean old
ip netns del "$NS" 2>/dev/null || true
ip link del "$VETH_HOST" 2>/dev/null || true

# create netns + veth
ip netns add "$NS"
ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
ip link set "$VETH_NS" netns "$NS"

ip addr add "$HOST_IP" dev "$VETH_HOST"
ip link set "$VETH_HOST" up

ip netns exec "$NS" ip link set lo up
ip netns exec "$NS" ip addr add "$NS_IP" dev "$VETH_NS"
ip netns exec "$NS" ip link set "$VETH_NS" up
ip netns exec "$NS" ip route replace default via 10.200.200.1

# enable forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# nft NAT + forward
nft flush ruleset || true

nft add table inet nat
nft 'add chain inet nat postrouting { type nat hook postrouting priority srcnat; policy accept; }'
nft add rule inet nat postrouting ip saddr 10.200.200.0/24 masquerade

nft add table inet filter
nft 'add chain inet filter forward { type filter hook forward priority filter; policy accept; }'

# make sure endpoint is reachable via veth before WG becomes default inside ns
EP_IP="$(awk -F'[ =:]+' '/^Endpoint/ {print $3; exit}' "$CFG")"
if [[ -n "${EP_IP:-}" ]]; then
  ip netns exec "$NS" ip route replace "${EP_IP}/32" via 10.200.200.1 dev "$VETH_NS" || true
fi

# bring up AmneziaWG inside netns
ip netns exec "$NS" awg-quick up "$CFG"
EOF
sudo chmod 755 "$VPNNS_UP"

echo "== write vpnns-down (idempotent) =="
sudo tee "$VPNNS_DOWN" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

NS="vpnns"
CFG="/etc/amneziawg/nl.conf"

ip netns exec "$NS" awg-quick down "$CFG" 2>/dev/null || true
ip netns del "$NS" 2>/dev/null || true
ip link del veth-vpn 2>/dev/null || true

nft delete table inet nat 2>/dev/null || true
nft delete table inet filter 2>/dev/null || true
EOF
sudo chmod 755 "$VPNNS_DOWN"

echo "== write systemd unit =="
sudo tee "$UNIT_FILE" >/dev/null <<'EOF'
[Unit]
Description=VPN network namespace (AmneziaWG) for Codex / OpenAI
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/vpnns-up
ExecStop=/usr/local/sbin/vpnns-down
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

echo "== enable/start service =="
sudo systemctl daemon-reload
sudo systemctl enable --now vpnns.service

echo "== smoke test (should be VPN IP) =="
sudo ip netns exec vpnns curl -4 --max-time 12 https://api.ipify.org
echo
echo "✅ done"
