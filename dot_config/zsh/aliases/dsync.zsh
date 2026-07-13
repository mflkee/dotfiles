# Aliases for dsync (dotfiles sync via chezmoi + NetBird)
#
# dsync already supports project/repository sync via: dsync project status|sync|clone
# Config: ~/.config/dsync/config.toml, section [projects]
# Example project entry:
#   [projects]
#   myapp = { path = "~/projects/myapp", remote = "git@github.com:mflkee/myapp.git", machines = ["notebook", "desktop"], branch = "main" }

# Main commands
alias ds='dsync status'
alias dss='dsync sync'
alias dsp='dsync push'
alias dspull='dsync pull'

# Edit encrypted secrets and sync everywhere
# Uses chezmoi edit (decrypts for editing, re-encrypts on save) and dsync sync.
alias dsync-secrets='chezmoi edit ~/.config/zsh/secrets.zsh && dsync sync'

# Show detailed dsync help
alias dsync-help='dsync help'

# Quick status of all machines
alias dsm='dsync status'

# Setup SSH access for all configured machines
alias dsetup='dsync setup'

# Discover/update machines from NetBird
alias ddiscover='dsync discover'

# Manage systemd timer
alias dtimer-on='dsync timer --enable'
alias dtimer-off='dsync timer --disable'

# Project / git repository sync
alias dps='dsync project status'
alias dpsync='dsync project sync'
alias dpclone='dsync project clone'

# Zen browser profile sync
alias dzen-export='dsync zen export'
alias dzen-import='dsync zen import'
