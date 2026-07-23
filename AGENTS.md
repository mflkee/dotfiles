# Dotfiles Rules

- This repository is the source of truth for files managed by chezmoi.
- Never edit live files under `~/.config`, `~/.tmux.conf`, `~/.zshrc`, or similar paths directly when a matching source file exists here.
- Prefer editing files in this repo directly, or use `chezmoi edit <target> --apply`.
- Treat `/home/mflkee/.local/share/chezmoi` and `/home/mflkee/dotfiles` as the same source repository.

# Infrastructure

## Centralized Obsidian on server-tmn
- **Server**: `mkair-server-tmn` (Netbird IP: `100.89.18.223`)
- **Vault**: `~/obs_main` (git-synced via bare repo at `server-tmn:obs_main.git`)
- **REST API**: `http://100.89.18.223:27123` (HTTP) and `https://100.89.18.223:27124` (HTTPS)
- **MCP Endpoints**: `/mcp` (obsidian-api) and `/second-brain-mcp/` (obsidian-second-brain)
- **API Key**: Stored in `OBSIDIAN_API_KEY` env var
- **systemd service**: `obsidian.service` (user service, runs headless with xvfb)
- **Plugin**: `obsidian-local-rest-api` v4.1.3 with `bindingHost: "0.0.0.0"`

### How to update vault on server-tmn
```bash
# From desktop (or any machine with vault):
cd ~/obs_main
git add -A && git commit -m "description"
git push server-tmn master:main

# On server-tmn:
cd ~/obs_main && git pull
systemctl --user restart obsidian.service
```

### How to access Obsidian from any machine
All opencode configs point to `http://100.89.18.223:27123` for MCP access.
Use the same API key as configured in `OBSIDIAN_API_KEY` env var.
