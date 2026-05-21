# System utilities
alias szsh="source ~/.zshrc"
alias sysoff="sudo shutdown now"
alias du="dust"
alias cat="bat"
alias ls="lsd"
alias ll="lsd -l"
alias l="lsd -l -a"
alias grep="rg"
alias top="btop"
# tldr как первый выбор, но если не найдено — показываем настоящий man
alias man='_(){ tldr "$1" 2>/dev/null || /usr/bin/man "$@"; };_'
alias ps="procs"
alias wh="which"
alias clean="~/.config/scripts/archclean.sh"
alias zf="zoxide-fzf"
alias wcopy='wl-copy'
alias dt='~/.config/scripts/utils/dt.sh'
alias zb='zen-browser'
alias um="sudo reflector --country Russia --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Sy && echo '✓ Зеркала обновлены'"
