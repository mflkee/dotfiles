# Машины и MCP

## Сеть и топология

Полная актуальная карта — **Obsidian vault `obs_main/servers/mesh-map.md`** (всегда читать её, не подразумевать).
Кратко: ssh/dsync/Obsidian-REST ходят по **NetBird**; Syncthing-файлы сейчас по **Tailscale**
(у всех устройств `address=dynamic`, listen `0.0.0.0:22000`, GUI только `127.0.0.1:8384`).
Hub = archlinux-server (Syncthing-хаб + dsync QUIC UDP `0.0.0.0:42069`); dsync-клиенты подключаются по NetBird `100.89.126.211:42069`.

## Текущие машины

| Имя | SSH | IP NetBird | В Syncthing? |
|-----|-----|-----------|--------------|
| archlinux-mkair (эта) | `ssh mkair` | 100.89.59.195 | да (MWBTMTZ) |
| archlinux-server (hub) | `ssh server` | 100.89.126.211 | да (QX6QAG5) |
| desktop | `ssh desktop` | 100.89.12.158 | да (3WAB5DG) |
| notebook | `ssh notebook` | 100.89.198.212 | да (SAAGLVR) |
| antix1 | `ssh antix1` | 100.89.195.135 | нет |
| mkair-server-tmn | `ssh mkair-server-tmn` | 100.89.18.223 | нет (UPS) |

## MCP-серверы

| Имя | Тип | Зачем |
|-----|-----|-------|
| `obsidian` | local | Чтение/запись vault |
| `github` | local | Репозитории |
| `netbird` | local | Управление пирами NetBird |
| `sync-ops` | local | Syncthing (папки/устройства/статус) + dsync (status/doctor/push/pull). Источник: `scripts/sync-ops-mcp.js` |

## dsync

- `dsync status` — здоровье машин и hub-состояние
- `dsync push` — запушить zen+проекты на hub; `dsync pull` — стянуть с hub
- Syncthing смотреть через MCP `sync-ops` (тулы `st-*`), а не через dsync
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
