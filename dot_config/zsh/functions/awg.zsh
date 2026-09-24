# awgq - обёртка для Python CLI + быстрые команды
# Неизвестные команды передаются в Python awgq (mesh = NetBird)
awgq() {
  local unit="${AWG_QUICK_UNIT:-awg-quick@wg0.service}"
  local target="${AWG_RT_TARGET:-100.89.126.211}"

  case "$1" in
    ("" | status) command awgq status ;;
    (on | up | start)
      sudo systemctl start "$unit"
      sleep 2
      command awgq mesh fix
      ;;
    (off | down | stop)
      sudo systemctl stop "$unit"
      ;;
    (restart)
      sudo systemctl restart "$unit"
      sleep 2
      command awgq mesh fix
      ;;
    (toggle) if systemctl is-active --quiet "$unit"
      then
        sudo systemctl stop "$unit"
      else
        sudo systemctl start "$unit"
        sleep 2
        command awgq mesh fix
      fi ;;
    (autostart-off | disable) sudo systemctl disable "$unit" ;;
    (autostart-on | enable) sudo systemctl enable "$unit" ;;
    (route) ip route get "${2:-$target}" ;;
    (mesh-fix | fix) command awgq mesh fix ;;
    (netbird-fix) command awgq netbird fix ;;
    (help | -h | --help)
      cat <<EOF
Usage: awgq <command> [target]

Shell commands (fast, no Python):
  on, up, start          Start VPN + apply mesh fix (NetBird)
  off, down, stop        Stop VPN
  restart                Restart VPN + apply mesh fix
  toggle                 Toggle VPN on/off
  status                 Show VPN status
  route [target]         Show route to target (default: ${target})
  mesh-fix               Apply NetBird route fix
  autostart-on           Enable VPN autostart
  autostart-off          Disable VPN autostart

Python commands (config management, TUI):
  config [name]          Select or list configs
  configs                Manage configs (list/add/remove/import)
  tui                    Interactive TUI mode
  setup                  Install configs
  logs                   Show logs
  netbird                NetBird mesh commands (status/fix/up/down)
  mesh                   Mesh VPN commands

  help                   Show this help
EOF
      ;;
    (*)
      command awgq "$@"
      ;;
  esac
}