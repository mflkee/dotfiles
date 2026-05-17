# awgq - обёртка для Python CLI + быстрые команды
# Неизвестные команды передаются в Python awgq
awgq() {
  local unit="${AWG_QUICK_UNIT:-awg-quick@wg0.service}"
  local app_unit="${AMNEZIA_VPN_UNIT:-AmneziaVPN.service}"
  local tailnet_cidr="${TAILSCALE_CIDR:-100.64.0.0/10}"
  local tailscale_table="${TAILSCALE_ROUTE_TABLE:-52}"
  local tailscale_rule_pref="${TAILSCALE_RULE_PREF:-70}"
  local tailscale_fwmark="${TAILSCALE_FWMARK:-0x80000/0xff0000}"
  local tailscale_fwmark_rule_pref="${TAILSCALE_FWMARK_RULE_PREF:-85}"
  local awg_table="${AWG_TABLE:-51820}"
  local old_tailscale_rule_prefs=("${(@s: :)${TAILSCALE_OLD_RULE_PREFS:-80 90 100 5190 5200}}")
  local dropin_dir="/etc/systemd/system/${unit}.d"
  local dropin_file="${dropin_dir}/tailscale-rule.conf"
  local tailscaled_dropin_dir="/etc/systemd/system/tailscaled.service.d"
  local tailscaled_dropin_file="${tailscaled_dropin_dir}/awg-tailscale-fix.conf"
  local fix_service="awg-tailscale-fix.service"
  local fix_service_file="/etc/systemd/system/${fix_service}"
  local fix_script="/usr/local/bin/awg-tailscale-fix"
  local target="${2:-100.80.114.18}"

  case "$1" in
    ("" | status) systemctl status "$unit" "$app_unit" --no-pager ;;
    (on | up | start)
      sudo systemctl start "$unit"
      sleep 2
      awgq ts-fix
      ;;
    (off | down | stop)
      sudo systemctl stop "$unit"
      ;;
    (restart)
      sudo systemctl restart "$unit"
      sleep 2
      awgq ts-fix
      ;;
    (toggle) if systemctl is-active --quiet "$unit"
      then
        sudo systemctl stop "$unit"
      else
        sudo systemctl start "$unit"
        sleep 2
        awgq ts-fix
      fi ;;
    (autostart-off | disable) sudo systemctl disable "$unit" "$app_unit" ;;
    (autostart-on | enable) sudo systemctl enable "$unit" "$app_unit" ;;
    (disable-now) sudo systemctl disable --now "$unit" "$app_unit" ;;
    (app-off) sudo systemctl stop "$app_unit" ;;
    (app-on) sudo systemctl start "$app_unit" ;;
    (route) ip route get "$target" ;;
    (tailscale-fix | ts-fix)
      # Динамически определяем приоритет AWG правила
      local awg_priority
      awg_priority=$(ip rule show | command grep -E "lookup ${awg_table}" | head -1 | cut -d: -f1 | tr -d ' ')
      if [[ -n "$awg_priority" ]]; then
        local dynamic_pref=$((awg_priority - 1))
        while [[ "$dynamic_pref" -gt 0 ]]; do
          if ! ip rule show | command grep -q "^${dynamic_pref}:"; then
            break
          fi
          dynamic_pref=$((dynamic_pref - 1))
        done
        [[ "$dynamic_pref" -lt 0 ]] && dynamic_pref=0
        tailscale_rule_pref="$dynamic_pref"
        echo "AWG rule at priority ${awg_priority}, placing Tailscale rule at priority ${tailscale_rule_pref}"
      else
        echo "AWG rule not found, using default priority ${tailscale_rule_pref}"
      fi

      local old_pref
      for old_pref in $(ip rule show | command grep -E "to ${tailnet_cidr} lookup ${tailscale_table}" | cut -d: -f1 | tr -d ' '); do
        sudo ip rule del pref "$old_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2> /dev/null || true
      done
      for old_pref in "$old_tailscale_rule_prefs[@]"; do
        [[ "$old_pref" == "$tailscale_rule_pref" ]] && continue
        sudo ip rule del pref "$old_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2> /dev/null || true
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
      sudo ip route flush cache 2>/dev/null || true
      ip route get "$target"
      ;;
    (tailscale-unfix | ts-unfix)
      local old_pref
      sudo ip rule del pref "$tailscale_fwmark_rule_pref" fwmark "$tailscale_fwmark" lookup main 2>/dev/null || true
      sudo ip rule del pref "$tailscale_rule_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2>/dev/null || true
      for old_pref in $(ip rule show | command grep -E "to ${tailnet_cidr} lookup ${tailscale_table}" | cut -d: -f1 | tr -d ' '); do
        sudo ip rule del pref "$old_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2>/dev/null || true
      done
      for old_pref in "$old_tailscale_rule_prefs[@]"; do
        sudo ip rule del pref "$old_pref" to "$tailnet_cidr" lookup "$tailscale_table" 2>/dev/null || true
      done
      sudo ip route flush cache 2>/dev/null || true
      ip route get "$target"
      ;;
    (install-systemd-fix | persist-fix)
      sudo mkdir -p "$dropin_dir" "$tailscaled_dropin_dir" "${fix_script:h}"
      cat <<EOF | sudo tee "$fix_script" > /dev/null
#!/bin/sh
set -eu

tailnet_cidr="${tailnet_cidr}"
tailscale_table="${tailscale_table}"
tailscale_rule_pref="${tailscale_rule_pref}"
tailscale_fwmark="${tailscale_fwmark}"
tailscale_fwmark_rule_pref="${tailscale_fwmark_rule_pref}"
awg_table="${awg_table}"
old_tailscale_rule_prefs="${old_tailscale_rule_prefs[*]}"
target="\${1:-${target}}"
iterations="\${2:-0}"
sleep_interval="\${3:-2}"

ensure_rule() {
  # Динамически определяем приоритет AWG правила
  local awg_priority
  awg_priority=$(/usr/bin/ip rule show | /usr/bin/grep -E "lookup \$awg_table" | /usr/bin/head -1 | /usr/bin/cut -d: -f1 | /usr/bin/tr -d ' ')
  if [ -n "\$awg_priority" ]; then
    local dynamic_pref=$((awg_priority - 1))
    while [ "\$dynamic_pref" -gt 0 ]; do
      if ! /usr/bin/ip rule show | /usr/bin/grep -q "^\${dynamic_pref}:"; then
        break
      fi
      dynamic_pref=$((dynamic_pref - 1))
    done
    [ "\$dynamic_pref" -lt 0 ] && dynamic_pref=0
    tailscale_rule_pref="\$dynamic_pref"
  fi

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
      sudo chmod +x "$fix_script"
      cat <<EOF | sudo tee "$dropin_file" > /dev/null
[Service]
ExecStartPost=/usr/bin/systemctl restart --no-block ${fix_service}
EOF
      cat <<EOF | sudo tee "$tailscaled_dropin_file" > /dev/null
[Service]
ExecStartPost=/usr/bin/systemctl restart --no-block ${fix_service}
EOF
      cat <<EOF | sudo tee "$fix_service_file" > /dev/null
[Unit]
Description=Fix Tailscale routing after AWG VPN start
After=network.target

[Service]
Type=oneshot
ExecStart=${fix_script}
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
      sudo systemctl daemon-reload
      sudo systemctl enable --now "$fix_service"
      ;;
    (uninstall-systemd-fix)
      sudo rm -f "$fix_script" "$dropin_file" "$tailscaled_dropin_file" "$fix_service_file"
      sudo systemctl daemon-reload
      ;;
    (help | -h | --help)
      cat <<EOF
Usage: awgq <command> [target]

Shell commands (fast, no Python):
  on, up, start          Start VPN + apply tailscale fix
  off, down, stop        Stop VPN
  restart                Restart VPN + apply tailscale fix
  toggle                 Toggle VPN on/off (with fix)
  status                 Show VPN status
  route [target]         Show route to target (default: ${target})
  ts-fix                 Apply tailscale routing fix
  ts-unfix               Remove tailscale routing fix
  persist-fix            Install systemd auto-fix service
  autostart-on           Enable VPN autostart
  autostart-off          Disable VPN autostart

Python commands (config management, TUI):
  config [name]          Select or list configs
  configs                Manage configs (list/add/remove/import)
  tui                    Interactive TUI mode
  setup                  Install configs from ~/Documents/vpns16.05/
  logs                   Show logs
  test                   Run tests
  profile                Manage profiles

  help                   Show this help
EOF
      ;;
    (config | configs | setup | tui | logs | test | profile)
      command awgq "$@"
      ;;
    (*)
      echo "Unknown command: $1" >&2
      command awgq "$@" 2>/dev/null || awgq help
      return 1
      ;;
  esac
}
