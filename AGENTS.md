# Dotfiles Rules

- This repository is the source of truth for files managed by chezmoi.
- Never edit live files under `~/.config`, `~/.tmux.conf`, `~/.zshrc`, or similar paths directly when a matching source file exists here.
- Prefer editing files in this repo directly, or use `chezmoi edit <target> --apply`.
- The chezmoi source repo is `/home/mflkee/dotfiles` (`chezmoi source-path`).

# Infrastructure

## Centralized Obsidian on archlinux-server
- **Server**: `archlinux-server` (Netbird IP: `100.89.126.211`)
- **Vault**: `~/obs_main` — synced across machines via **Syncthing** (folder `nzf3f-a9q4c`, sendreceive), NOT git push
- **REST API**: `http://100.89.59.195:27123` (via archlinux-mkair) and `https://100.89.59.195:27124`
- **MCP Endpoints**: `/second-brain-mcp/` (obsidian-second-brain)
- **API Key**: Stored in `OBSIDIAN_API_KEY` env var

### How to edit the vault
```bash
# On any machine — just edit; Syncthing propagates to all machines automatically.
# Optionally snapshot locally for versioning (NOT pushed anywhere):
cd ~/obs_main && git add -A && git commit -m "description"
```

## dsync v2 (Rust, replaces old Python v1)
- **Hub**: `archlinux-server:42069` (QUIC), systemd user unit `dsync-hub.service`, `loginctl enable-linger mflkee` enabled. Data: `~/.local/share/dsync-hub/machines.json`
- **Clients**: `~/.local/bin/dsync`, config `~/.config/dsync/dsync/config.toml` (chezmoi template), 15-min `dsync.timer` on desktop/mkair/notebook
- **Flow**: client pushes state → hub stores → hub SSH-pulls `dotfiles` + `dsync` на все машины (`git pull --rebase --autostash` — незакоммиченная работа не теряется) + runs `post_pull` (dotfiles: `chezmoi apply`, dsync: rebuild бинаря)
- **`~/projects` — НЕ Syncthing (отменено 2026-09-24)**: Syncthing-папка `projects` удалена со всех машин (синк `.git` файлами — анти-паттерн, рвал `.git`). Теперь **каждая машина сама** работает с репо через **git+GitHub** (`git@github.com:mflkee/…`); dsync только **анонсирует состояния** (`[auto_projects] sync = false`: ветка, dirty, ahead/behind — смотрится в `dsync tui` → Projects), НО не разворачивает и не автокоммитит их. Пулятся только явные `[projects.*]` = `dotfiles` + `dsync`. Дисциплина: git-операции по репо — в один момент на одной машине, при совместной работе — pull/merge через GitHub.
- **Machine names**: desktop, notebook, archlinux-mkair, archlinux-server. Hostname mapping: archlinux-desktop→desktop, archlinux-notebook→notebook, archlinux-mkair→archlinux-mkair, archlinux-server→archlinux-server. Notebook SSH-pull by IP `100.89.198.212`
- **Source**: `~/projects/dsync`; build: `cargo build --release`, deploy binary to `~/.local/bin/dsync` (client) / `dsync-hub` (server)
- **Note**: binary is a single ~18MB ELF with rustls (no cert verification)
- **Секреты**: per-machine токен хаба — sidecar `~/.config/dsync/dsync/tokens.toml` (0600, chezmoi-ignored, в git не попадает). Новой машине его надо завести вручную (`[hub_connect] token = "…"` из `[hub] tokens` на сервере), иначе хаб отвергнет запросы и машина будет «offline».

### Dotfiles: no `chezmoi edit` needed (auto-capture)
- Любую правку живого файла (~/.zshrc, ~/.config/...) или исходника в
  `~/dotfiles` можно делать напрямую (nvim, bash, sed) — `dsync` сам забирает
  её в репозиторий при каждом `dsync push` (сравнение sha256 по
  `~/.local/share/dsync/capture-state.json`, погнал `chezmoi re-add`; правки
  исходников применяются локально через `chezmoi apply --force`).
- nvim-хук `~/.config/nvim/lua/custom/plugins/dsync-capture.lua` делает это
  мгновенно на каждое `:w` (вызов `dsync capture <path>`). Отключить:
  `let g:dsync_capture_enabled = v:false`.
- Не захватываются: файлы с исходником `.tmpl` (правь шаблон), сгенерированные
  темы/`.desktop`, `~/Pictures`, вложенные git-репо и не-managed файлы.

### Синхронизация состояния: tmux + сессии opencode
- Управляется секцией `[state]` в конфиге (chezmoi-шаблон) и работает
  автоматически в `dsync push`/`pull`/`watch` — через хаб (сообщения
  `state_push`/`state_pull`, хранилище `~/.local/share/dsync-hub/state/`).
- **tmux**: синхронизируется последний снапшот tmux-resurrect
  (`~/.local/share/tmux/resurrect/`); на приёмнике файл раскладывается,
  восстановить в живой tmux — `prefix + Ctrl-r` (или `tmux_restore = true`).
- **opencode**: синхронизируются сессии по всем `[projects.*]` (можно сузить:
  `[state.opencode] projects = ["~/projects/…"]`). На машине-источнике —
  `session list --format json` → `session export` изменившихся; на других —
  `session import`. Экспорт идёт с `--standalone` (в V2 экспорт через общий
  сервис недетерминированно обрезается — баг CLI).
- Локальный индекс `~/.local/share/dsync/state.json`; сбойные элементы не
  теряются (seq откатывается), только что импортированное не пере-отправляется.
- **opencode нужен V2** (`@opencode/cli` → `~/.opencode/bin/opencode`), иначе
  сессии не синкаются (tmux при этом работает).

### How to access Obsidian from any machine
- `obsidian-memory` MCP — reads vault files locally (via Syncthing)
- `obsidian-second-brain` MCP — points to `archlinux-mkair:27123` (running Obsidian with plugins)

## UPS / ИБП на mkair-server-tmn (NUT)
- **Сервер**: `mkair-server-tmn` (Netbird IP: `100.89.18.223`)
- **ИБП**: APC Smart-UPS 1500 (FW 653.19.I), подключён по USB (vendor `051d`, product `0002`)
- **ПО**: NUT 2.8.5 (`pacman -S nut`)
- **Скрипт завершения**: `/usr/local/bin/graceful-shutdown` — останавливает Docker-контейнеры (SIGTERM, 60с), sync, `systemctl poweroff`
- **Логика**: питание пропало → ИБП на батарее → 10 минут (OFFDURATION 600) → graceful-shutdown → poweroff

### Конфиги NUT
| Файл | Описание |
|------|----------|
| `/etc/nut/nut.conf` | `MODE=standalone` |
| `/etc/nut/ups.conf` | `[apc-ups]`, driver=`usbhid-ups`, port=`auto` |
| `/etc/nut/upsmon.conf` | `MONITOR apc-ups@localhost 1 monuser nutmon master`, `OFFDURATION 600`, `SHUTDOWNCMD "/usr/local/bin/graceful-shutdown"` |
| `/etc/nut/upsd.conf` | `LISTEN 127.0.0.1 3493` |
| `/etc/nut/upsd.users` | пользователь `monuser` |
| `/etc/udev/rules.d/99-nut-usbups.rules` | доступ к USB для группы `nut` |

### Сервисы (systemd)
```
nut-driver@apc-ups.service   enabled + active
nut-server.service           enabled + active
nut-monitor.service          enabled + active
```

### Проверка
```bash
ssh mkair-server-tmn "upsc apc-ups"           # статус ИБП
ssh mkair-server-tmn "upsc apc-ups ups.status"  # OL = от сети, OB = батарея
ssh mkair-server-tmn "upsc apc-ups battery.charge"  # процент заряда
ssh mkair-server-tmn "journalctl -u nut-monitor -f"  # лог upsmon
```

## NetBird MCP (machine management)
- Opencode has a built-in NetBird MCP tool (`netbird` MCP server).
- Requires `NETBIRD_API_KEY` env var (personal access token from NetBird dashboard).
- Available tools: `list-peers`, `get-peer`, `get-peer-by-ip`, `rename-peer`.
- **Secrets**: `NETBIRD_API_KEY` stored in `~/.config/zsh/secrets.zsh` (encrypted via chezmoi+age).
  Source before starting opencode: `source ~/.config/zsh/secrets.zsh`

## AmneziaWG / awgq (терминальный VPN-клиент)
- **`awgq`** — Python CLI/TUI (`~/projects/awgq`, symlink `~/.local/bin/awgq -> ~/projects/awgq/awgq.sh`, venv в `~/projects/awgq/.venv`). Установлен и настроен на **notebook и archlinux-mkair** (mesh = **NetBird**, `wt0`/table `7120`; Tailscale удалён со всех машин).
- Конфиги VPN: `/etc/amnezia/amneziawg/configs/` (активный — симлинк `/etc/amnezia/amneziawg/wg0.conf`). Конфиг awgq: `~/.config/awgq/config.yaml` (в chezmoi).
- **Команды**: `awgq on/off/toggle/restart` (systemd `awg-quick@wg0.service` + netbird-fix), `awgq config <имя>`, `awgq status`, `awgq netbird fix`, `awgq tui`. zsh-обёртка: `~/.config/zsh/functions/awg.zsh`.
- **Критично**: один конфиг = один ключ = **одно активное устройство одновременно** (у провайдера лимит до 5 устройств, но шарение одного ключа ведёт к «качелям»/лагам по всей сети). Для каждого устройства — свой конфиг/ключ. После разбора 2026-09-24: VPN на ноутах выключен (`disabled`), дом работает на Keenetic.
- **Пакеты**: `amneziawg-linux` (модуль ядра), `amneziawg-tools` (`awg-quick`), `amneziawg-go` (userspace, опционально). Нужен `openresolv` (иначе `resolvconf: command not found`).
