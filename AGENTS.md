# Dotfiles Rules

- This repository is the source of truth for files managed by chezmoi.
- Never edit live files under `~/.config`, `~/.tmux.conf`, `~/.zshrc`, or similar paths directly when a matching source file exists here.
- Prefer editing files in this repo directly, or use `chezmoi edit <target> --apply`.
- Treat `/home/mflkee/.local/share/chezmoi` and `/home/mflkee/dotfiles` as the same source repository.

# Infrastructure

## Centralized Obsidian on archlinux-server
- **Server**: `archlinux-server` (Netbird IP: `100.89.126.211`)
- **Vault**: `~/obs_main` (git-synced via bare repo at `archlinux-server:obs_main.git`)
- **REST API**: `http://100.89.59.195:27123` (via archlinux-mkair) and `https://100.89.59.195:27124`
- **MCP Endpoints**: `/second-brain-mcp/` (obsidian-second-brain)
- **API Key**: Stored in `OBSIDIAN_API_KEY` env var

### How to update vault on archlinux-server
```bash
# From desktop (or any machine with vault):
cd ~/obs_main
git add -A && git commit -m "description"
git push archlinux-server master:main

# On archlinux-server:
cd ~/obs_main && git pull
```

### How to access Obsidian from any machine
- `obsidian-memory` MCP — reads vault files locally (via Syncthing)
- `obsidian-second-brain` MCP — points to `archlinux-mkair:27123` (running Obsidian with plugins)

## NetBird MCP (machine management)
- Opencode has a built-in NetBird MCP tool (`netbird` MCP server).
- Requires `NETBIRD_API_KEY` env var (personal access token from NetBird dashboard).
- Available tools: `list-peers`, `get-peer`, `get-peer-by-ip`, `rename-peer`.
- **Secrets**: `NETBIRD_API_KEY` stored in `~/.config/zsh/secrets.zsh` (encrypted via chezmoi+age).
  Source before starting opencode: `source ~/.config/zsh/secrets.zsh`
