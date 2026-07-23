# Мои NetBird-машины и dsync

У пользователя есть личная сеть NetBird и утилита `dsync` для синхронизации dotfiles (через chezmoi).

## Текущая машина

- **desktop** — `mflkee@100.89.12.158` (`archlinux-desktop-12-158.netbird.cloud`)

## Целевые машины для dsync / SSH

| Имя | SSH (user@IP) | FQDN | Статус NetBird |
|-----|---------------|------|----------------|
| notebook | `mflkee@100.89.198.212` | `archlinux-notebook-198-212.netbird.cloud` | connected |
| desktop | `mflkee@100.89.12.158` | `archlinux-desktop-12-158.netbird.cloud` | connected (текущая) |
| archlinux-mkair | `mflkee@100.89.59.195` | `archlinux-mkair.netbird.cloud` | connected (P2P) |
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
- **obsidian-memory** — работа с Obsidian vault локально (через Syncthing).
- **obsidian-second-brain** — семантический поиск по wiki (remote, archlinux-mkair:27123).
- **netbird** — управление пирами NetBird. Требует `NETBIRD_API_KEY` в `secrets.zsh`.

Перед запуском opencode убедись, что secrets загружены: `source ~/.config/zsh/secrets.zsh`.

Obsidian vault (`~/obs_main`) синхронизируется между машинами через Syncthing.

## Маппинг машин ↔ Obsidian

| NetBird peer | IP | Obsidian note |
|---|---|---|
| archlinux-server | 100.89.126.211 | `machines/archlinux-server.md` |
| archlinux-mkair | 100.89.59.195 | `machines/archlinux-mkair.md` |
| archlinux-notebook | 100.89.198.212 | `machines/archlinux-notebook.md` |
| archlinux-desktop | 100.89.12.158 | `machines/archlinux-desktop.md` |
| antix1 | 100.89.195.135 | `machines/antix1.md` |
