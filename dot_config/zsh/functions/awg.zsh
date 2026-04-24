# Manage AmneziaWG from the shell without changing network state on shell startup.
awgq() {
  local unit="${AWG_QUICK_UNIT:-awg-quick@wg0.service}"
  local app_unit="${AMNEZIA_VPN_UNIT:-AmneziaVPN.service}"
  local tailnet_cidr="${TAILSCALE_CIDR:-100.64.0.0/10}"
  local tailscale_table="${TAILSCALE_ROUTE_TABLE:-52}"
  local tailscale_rule_pref="${TAILSCALE_RULE_PREF:-100}"
  local tailscale_fwmark="${TAILSCALE_FWMARK:-0x80000/0xff0000}"
  local tailscale_fwmark_rule_pref="${TAILSCALE_FWMARK_RULE_PREF:-90}"
  local old_tailscale_rule_prefs=("${(@s: :)${TAILSCALE_OLD_RULE_PREFS:-5190 5200}}")
  local dropin_dir="/etc/systemd/system/${unit}.d"
  local dropin_file="${dropin_dir}/tailscale-rule.conf"
  local tailscaled_dropin_dir="/etc/systemd/system/tailscaled.service.d"
  local tailscaled_dropin_file="${tailscaled_dropin_dir}/awg-tailscale-fix.conf"
  local fix_service="awg-tailscale-fix.service"
  local fix_service_file="/etc/systemd/system/${fix_service}"
  local fix_script="/usr/local/bin/awg-tailscale-fix"
  local target="${2:-100.80.114.18}"

  case "$1" in
    ""|status)
      systemctl status "$unit" "$app_unit" --no-pager
      ;;
    on|up|start)
      sudo systemctl start "$unit"
      ;;
    off|down|stop)
      sudo systemctl stop "$unit"
      ;;
    restart)
      sudo systemctl restart "$unit"
      ;;
    toggle)
      if systemctl is-active --quiet "$unit"; then
        sudo systemctl stop "$unit"
      else
        sudo systemctl start "$unit"
      fi
      ;;
    autostart-off|disable)
      sudo systemctl disable "$unit" "$app_unit"
      ;;
    autostart-on|enable)
      sudo systemctl enable "$unit" "$app_unit"
      ;;
    disable-now)
      sudo systemctl disable --now "$unit" "$app_unit"
      ;;
    app-off)
      sudo systemctl stop "$app_unit"
      ;;
    app-on)
      sudo systemctl start "$app_unit"
      ;;
    route)
      ip route get "$target"
      ;;
    tailscale-fix|ts-fix)
      local old_pref
      for old_pref in "$old_tailscale_rule_prefs[@]"; do
        [[ "$old_pref" == "$tailscale_rule_pref" ]] && continue
        sudo ip rule del pref "$old_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2>/dev/null || true
      done
      if ! ip rule show | command grep -q "^${tailscale_fwmark_rule_pref}:.*fwmark ${tailscale_fwmark} lookup main$"; then
        if ip rule show | command grep -q "^${tailscale_fwmark_rule_pref}:"; then
          echo "ip rule priority ${tailscale_fwmark_rule_pref} is already in use." >&2
          echo "Set TAILSCALE_FWMARK_RULE_PREF to a free priority below the AWG rule and retry." >&2
          return 1
        fi
        sudo ip rule add pref "$tailscale_fwmark_rule_pref" fwmark "$tailscale_fwmark" lookup main
      fi
      if ! ip rule show | command grep -q "^${tailscale_rule_pref}:.*to ${tailnet_cidr} lookup ${tailscale_table}$"; then
        if ip rule show | command grep -q "^${tailscale_rule_pref}:"; then
          echo "ip rule priority ${tailscale_rule_pref} is already in use." >&2
          echo "Set TAILSCALE_RULE_PREF to a free priority below the AWG rule and retry." >&2
          return 1
        fi
        sudo ip rule add pref "$tailscale_rule_pref" to "$tailnet_cidr" lookup "$tailscale_table"
      fi
      ip route get "$target"
      ;;
    tailscale-unfix|ts-unfix)
      local old_pref
      sudo ip rule del pref "$tailscale_fwmark_rule_pref" fwmark "$tailscale_fwmark" lookup main 2>/dev/null || true
      sudo ip rule del pref "$tailscale_rule_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2>/dev/null || true
      for old_pref in "$old_tailscale_rule_prefs[@]"; do
        sudo ip rule del pref "$old_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2>/dev/null || true
      done
      ip route get "$target"
      ;;
    install-systemd-fix|persist-fix)
      sudo mkdir -p "$dropin_dir" "$tailscaled_dropin_dir" "${fix_script:h}"
      cat <<EOF | sudo tee "$fix_script" >/dev/null
#!/bin/sh
set -eu

tailnet_cidr="${tailnet_cidr}"
tailscale_table="${tailscale_table}"
tailscale_rule_pref="${tailscale_rule_pref}"
tailscale_fwmark="${tailscale_fwmark}"
tailscale_fwmark_rule_pref="${tailscale_fwmark_rule_pref}"
old_tailscale_rule_prefs="${old_tailscale_rule_prefs[*]}"
target="\${1:-${target}}"
iterations="\${2:-0}"
sleep_interval="\${3:-2}"

ensure_rule() {
  for old_pref in \$old_tailscale_rule_prefs; do
    [ "\$old_pref" = "\$tailscale_rule_pref" ] && continue
    /usr/bin/ip rule del pref "\$old_pref" to "\$tailnet_cidr" lookup "\$tailscale_table" 2>/dev/null || true
  done

  if ! /usr/bin/ip rule show | /usr/bin/grep -q "^\${tailscale_fwmark_rule_pref}:.*fwmark \${tailscale_fwmark} lookup main$"; then
    if /usr/bin/ip rule show | /usr/bin/grep -q "^\${tailscale_fwmark_rule_pref}:"; then
      echo "ip rule priority \${tailscale_fwmark_rule_pref} is already in use." >&2
      exit 1
    fi
    /usr/bin/ip rule add pref "\$tailscale_fwmark_rule_pref" fwmark "\$tailscale_fwmark" lookup main 2>/dev/null || true
  fi

  if /usr/bin/ip rule show | /usr/bin/grep -q "^\${tailscale_rule_pref}:.*to \${tailnet_cidr} lookup \${tailscale_table}$"; then
    return 0
  fi

  if /usr/bin/ip rule show | /usr/bin/grep -q "^\${tailscale_rule_pref}:"; then
    echo "ip rule priority \${tailscale_rule_pref} is already in use." >&2
    exit 1
  fi

  /usr/bin/ip rule add pref "\$tailscale_rule_pref" to "\$tailnet_cidr" lookup "\$tailscale_table" 2>/dev/null || true
}

i=0
while [ "\$iterations" = "0" ] || [ "\$i" -lt "\$iterations" ]; do
  ensure_rule
  i=\$((i + 1))
  /usr/bin/sleep "\$sleep_interval"
done

ensure_rule
/usr/bin/ip route get "\$target" 2>/dev/null || true
EOF
      sudo chmod 0755 "$fix_script"
      cat <<EOF | sudo tee "$fix_service_file" >/dev/null
[Unit]
Description=Keep Tailscale policy route ahead of AWG
After=tailscaled.service
Wants=tailscaled.service

[Service]
Type=simple
ExecStart=${fix_script} ${target} 0 2
Restart=always
RestartSec=5
EOF
      cat <<EOF | sudo tee "$dropin_file" >/dev/null
[Unit]
After=tailscaled.service
Wants=tailscaled.service

[Service]
ExecStartPost=-/usr/bin/systemctl restart --no-block ${fix_service}
ExecStopPost=-/usr/bin/systemctl stop ${fix_service}
ExecStopPost=-/usr/bin/ip rule del pref ${tailscale_fwmark_rule_pref} fwmark ${tailscale_fwmark} lookup main
ExecStopPost=-/usr/bin/ip rule del pref ${tailscale_rule_pref} to ${tailnet_cidr} lookup ${tailscale_table}
EOF
      cat <<EOF | sudo tee "$tailscaled_dropin_file" >/dev/null
[Service]
ExecStartPost=-/usr/bin/systemctl restart --no-block ${fix_service}
EOF
      sudo systemctl daemon-reload
      sudo systemctl restart --no-block "$fix_service"
      systemctl cat "$unit" "$fix_service" tailscaled.service
      ;;
    remove-systemd-fix|unpersist-fix)
      sudo systemctl stop "$fix_service" 2>/dev/null || true
      sudo rm -f "$dropin_file" "$tailscaled_dropin_file" "$fix_service_file" "$fix_script"
      sudo rmdir "$dropin_dir" 2>/dev/null || true
      sudo rmdir "$tailscaled_dropin_dir" 2>/dev/null || true
      sudo systemctl daemon-reload
      ;;
    show-systemd-fix)
      systemctl cat "$unit" "$fix_service" tailscaled.service
      ;;
    help|-h|--help)
      cat <<'EOF'
Usage: awgq <command>

Commands:
  status             show AWG and AmneziaVPN service status
  on|off|toggle      start, stop, or toggle awg-quick@wg0.service
  autostart-off      disable awg-quick@wg0.service and AmneziaVPN.service at boot
  autostart-on       enable awg-quick@wg0.service and AmneziaVPN.service at boot
  disable-now        disable autostart and stop both services now
  app-on|app-off     start or stop only AmneziaVPN.service
  route [ip]         show the kernel route for an IP, default mkair-server
  ts-fix [ip]        prefer Tailscale table 52 for 100.64.0.0/10 while AWG is up
  ts-unfix [ip]      remove the temporary Tailscale priority rule
  persist-fix        install systemd helper to keep Tailscale ahead of AWG
  unpersist-fix      remove that systemd helper
  show-systemd-fix   show AWG, helper, and Tailscale drop-ins

Examples:
  awgq off
  awgq autostart-off
  awgq ts-fix
  awgq persist-fix
EOF
      ;;
    *)
      echo "Unknown awgq command: $1" >&2
      echo "Run: awgq help" >&2
      return 2
      ;;
  esac
}

alias awg-toggle='awgq toggle'
alias awg-route='awgq route'
