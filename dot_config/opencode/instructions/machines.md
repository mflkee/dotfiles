# Машины и MCP

## Текущие машины

| Имя | SSH | IP NetBird | Статус |
|-----|-----|-----------|--------|
| notebook | `ssh notebook` | 100.89.198.212 | connected |
| desktop | (текущая) | 100.89.12.158 | connected |
| archlinux-server | `ssh archlinux-server` | 100.89.126.211 | connected |
| archlinux-mkair | `ssh archlinux-mkair` | 100.89.59.195 | connected |
| antix1 | `ssh antix1` | 100.89.195.135 | connected |
| mkair-server-tmn | `ssh mkair-server-tmn` | 100.89.18.223 | connected |

## MCP-серверы

| Имя | Тип | Зачем |
|-----|-----|-------|
| `obsidian` | local | Чтение/запись vault |
| `github` | local | Репозитории |
| `netbird` | local | Управление пирами NetBird |

## dsync

- `dsync status` — здоровье всех машин + Obsidian + Syncthing
- `dsync sync` — полная синхронизация dotfiles на все машины
- `dsync syncthing status` — Syncthing на всех машинах
- Secrets: `source ~/.config/zsh/secrets.zsh` перед opencode

## Маппинг машин ↔ Obsidian

| Машина | Заметка |
|--------|---------|
| archlinux-server | `servers/archlinux-server.md` |
| archlinux-mkair | `servers/archlinux-mkair.md` |
| archlinux-notebook | `servers/archlinux-notebook.md` |
| archlinux-desktop | `servers/archlinux-desktop.md` |
| antix1 | `servers/antix1.md` |

## mkair-server-tmn — ИБП (NUT)

- ИБП: APC Smart-UPS 1500 по USB
- NUT 2.8.5, драйвер `usbhid-ups`
- Graceful shutdown через `/usr/local/bin/graceful-shutdown` (Docker stop → sync → poweroff)
- Задержка до shutdown: 10 мин (OFFDURATION 600)
- Проверка: `ssh mkair-server-tmn "upsc apc-ups"`
