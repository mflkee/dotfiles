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
| server | `mflkee@100.89.59.195` | `mkair-server.netbird.cloud` | Connecting |
| antix1 | `mflkee@100.89.195.135` | `antix1.netbird.cloud` | connected (P2P) |
| archlinux-server | `mflkee@100.89.126.211` | `archlinux-server.netbird.cloud` | connected (P2P) |

## dsync

- `dsync` — CLI для синхронизации dotfiles через chezmoi по целевым машинам.
- Полезная команда для диагностики: `dsync status`.
- В `dsync` целевой хост `archlinux-server` указан как bare hostname и отображается offline. Актуальный FQDN: `archlinux-server.netbird.cloud`.

## MCP-серверы

В opencode настроены MCP-серверы:

- **github** — `@modelcontextprotocol/server-github`. Требует переменную `GITHUB_TOKEN` (передаётся как `GITHUB_PERSONAL_ACCESS_TOKEN`).
- **obsidian** — плагин Obsidian **Local REST API Second Brain MCP Extension**. Подключается через HTTP к `http://127.0.0.1:27123/second-brain-mcp/`. Требует:
  - родительский плагин `obsidian-local-rest-api` (включён и запущен в Obsidian);
  - плагин `obsidian-local-rest-api-second-brain-mcp-extension`;
  - переменную `OBSIDIAN_API_KEY` (копируется из настроек родительского плагина).

Перед запуском opencode экспортируй токены:

```bash
export GITHUB_TOKEN=ghp_...
export OBSIDIAN_API_KEY=...
```

Obsidian vault (`~/obs_main`) синхронизируется между машинами отдельно — через Syncthing (уже есть `.stfolder`).

