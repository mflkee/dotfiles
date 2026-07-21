# Мои NetBird-машины и dsync

У пользователя есть личная сеть NetBird и утилита `dsync` для синхронизации dotfiles (через chezmoi).

## Текущая машина

- **notebook** — `mflkee@100.89.198.212` (`archlinux-notebook-198-212.netbird.cloud`)

## Целевые машины для dsync / SSH

| Имя | SSH (user@IP) | FQDN | Статус NetBird |
|-----|---------------|------|----------------|
| notebook | `mflkee@100.89.198.212` | `archlinux-notebook-198-212.netbird.cloud` | connected (текущая) |
| desktop | `mflkee@100.89.12.158` | `archlinux-desktop-12-158.netbird.cloud` | Connecting |
| server-tmn | `mflkee@100.89.18.223` | `mkair-server-tmn.netbird.cloud` | connected (P2P) |
| archlinux-mkair | `mflkee@100.89.59.195` | `archlinux-mkair.netbird.cloud` (DNS обновляется) | Connecting |
| antix1 | `mflkee@100.89.195.135` | `antix1.netbird.cloud` | connected (P2P) |
| archlinux-server | `mflkee@100.89.126.211` | `archlinux-server.netbird.cloud` | connected (P2P) |

## dsync

- `dsync` — CLI для синхронизации dotfiles через chezmoi по целевым машинам.
- Полезная команда для диагностики: `dsync status`.
- Секреты: `~/.config/zsh/secrets.zsh` (зашифрован через age + chezmoi).
- `dsync sync` автоматически делает `chezmoi re-add` для secrets перед коммитом.

## MCP-серверы

В opencode настроены MCP-серверы:

- **github** — `@modelcontextprotocol/server-github`. Токен в `secrets.zsh`.
- **obsidian** — Second Brain MCP Extension (`http://127.0.0.1:27123/second-brain-mcp/`). Требует `OBSIDIAN_API_KEY` в `secrets.zsh`.
- **obsidian-memory** — встроенные инструменты для работы с Obsidian vault.

Перед запуском opencode убедись, что secrets загружены: `source ~/.config/zsh/secrets.zsh`.

Obsidian vault (`~/obs_main`) синхронизируется между машинами через Syncthing.
