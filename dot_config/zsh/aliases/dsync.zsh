# Aliases for dsync v2 (Rust) — hub-based sync over QUIC
#
# Server hub: archlinux-server:42069 (systemd user unit dsync-hub.service)
# Config: ~/.config/dsync/dsync/config.toml
# Commands: status, push, pull, doctor, daemon, bot
# What it syncs:
#   - git projects (dsync, dotfiles) — hub SSH-pulls repos on target machines
#     after each push, then runs post_pull (dotfiles: chezmoi apply)
#   - Zen browser profile — exported on push, imported on pull

# Main commands
alias ds='dsync status'
alias dsp='dsync push'
alias dspull='dsync pull'

# Diagnostics
alias dsync-help='dsync help'
alias ddoctor='dsync doctor'

# Edit encrypted secrets and push everywhere
alias dsync-secrets='chezmoi edit ~/.config/zsh/secrets.zsh && dsync push'
