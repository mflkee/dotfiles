# System utilities
alias szsh="source ~/.zshrc"
alias sysoff="sudo shutdown now"
alias du="dust"
alias cat="bat"
alias ls="lsd"
alias ll="lsd -l"
alias l="lsd -l -a"
alias grep="rg"
alias man="tldr"
alias top="gtop"
alias ps="procs"
alias wh="which"
alias clean="~/.config/scripts/archclean.sh"
alias zf="zoxide-fzf"
alias wcopy='wl-copy'
alias dt='~/.config/scripts/utils/dt.sh'

# vpn helper
vpn() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    on|up|connect)
      ~/.local/bin/vpn-manager connect "$@"
      ;;
    off|down|disconnect)
      ~/.local/bin/vpn-manager disconnect
      ;;
    toggle)
      ~/.local/bin/vpn-manager toggle
      ;;
    choice|menu|pick)
      ~/.local/bin/vpn-manager menu
      ;;
    list)
      ~/.local/bin/vpn-manager list
      ;;
    status)
      ~/.local/bin/vpn-manager status
      ;;
    current)
      ~/.local/bin/vpn-manager current
      ;;
    "")
      echo "Usage: vpn {on|off|toggle|choice|list|status|current} [name]" >&2
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Usage: vpn {on|off|toggle|choice|list|status|current} [name]" >&2
      ;;
  esac
}

# codex-vpn
alias codex-vpn='sudo ip netns exec vpnns env -i \
HOME="$HOME" USER="$USER" \
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
XDG_RUNTIME_DIR="/run/user/$(id -u)" \
codex'
