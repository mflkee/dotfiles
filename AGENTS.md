# Dotfiles Rules

- This repository is the source of truth for files managed by chezmoi.
- Never edit live files under `~/.config`, `~/.tmux.conf`, `~/.zshrc`, or similar paths directly when a matching source file exists here.
- Prefer editing files in this repo directly, or use `chezmoi edit <target> --apply`.
- Treat `/home/mflkee/.local/share/chezmoi` and `/home/mflkee/dotfiles` as the same source repository.
