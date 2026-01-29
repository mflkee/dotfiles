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

# codex-vpn
alias codex-vpn='sudo ip netns exec vpnns env -i \
HOME="$HOME" USER="$USER" \
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
XDG_RUNTIME_DIR="/run/user/$(id -u)" \
codex'

