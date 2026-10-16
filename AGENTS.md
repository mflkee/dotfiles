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
- **`~/projects` — НЕ Syncthing (отменено 2026-09-24)**: Syncthing-папка `projects` удалена со всех машин (синк `.git` файлами — анти-паттерн, рвал `.git`). Теперь **каждая машина сама** работает с репо через **git+GitHub** (`git@github.com:mflkee/…`); dsync только **анонсирует состояния** (`[auto_projects] sync = false`: ветка, dirty, ahead/behind — смотрится в `dsync tui` → Projects), НО не разворачивает и не автокоммитит их. Пулятся только явные `[projects.*]` = `dotfiles`, `dsync`, `awgq`, `passstore`. Дисциплина: git-операции по репо — в один момент на одной машине, при совместной работе — pull/merge через GitHub.
- **`passstore`** (с 2026-10-13): gopass-хранилище секретов, `~/.password-store` → `mflkee/passstore` (private). Раскатывается **без archlinux-server** (список `machines`): там приёмник бэкапов, а в хранилище лежит приватный ключ их расшифровки. Хаб раскатывает только проекты из своей копии конфига, поэтому проект описан на всех машинах, а ограничение задаёт `machines`; после правки списка хаб надо перезапустить. Детали — vault `servers/secret-store.md`.
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
- **Грабли (разобрано 2026-10-01)**: `tmux-continuum` в `.tmux.conf` обязан
  объявляться ПОСЛЕ `tmux-dotbar`. Загрузчик dotbar в конце перезаписывает
  `status-right`/`status-left` и затирает интерполяцию `#(continuum_save.sh)`,
  без которой автосейв continuum молча не работает: каталог
  `~/.local/share/tmux/resurrect/` не создаётся, и после ребута tmux пишет
  «Tmux resurrect file not found!». Проверка: `tmux show-options -g status-right`
  должен содержать `continuum_save.sh`.
- **dsync**: `collect_tmux` сам создаёт каталог снапшотов и сравнивает хеш
  раскладки через `has_exact` (точное равенство). Раньше сравнение было `>=`
  по числовому хешу — новый хеш меньше старого «залипал» в индексе, и tmux
  больше не пушился (хаб не получал снапшот вообще).
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

## Запись экрана / скриншоты (niri)
- **Основной путь записи** (с 2026-10-16; свой скрипт `screenrec-toggle.sh` удалён — был «визуально странный»):
  - **`Alt+Z`** — оверлей **gpu-screen-recorder-ui** (ShadowPlay-style). Пакет `gpu-screen-recorder-ui`,
    автозапуск `~/.config/autostart/gpu-screen-recorder-ui.desktop` → юнит
    `app-gpu\x2dscreen\x2drecorder\x2dui@autostart.service`, демон `gsr-ui launch-daemon`.
    Источники: монитор, `region`, **`portal`** (= диалог выбора окна/монитора), камеры; плюс replay-буфер,
    качество, хоткеи, настройки. Клавиши ловит сам через evdev (`/dev/input`, пользователь в группе `input`),
    поддержка композитора не нужна; работает через XWayland (`xwayland-satellite`).
    CLI (для биндов): `gsr-ui-cli toggle-show|toggle-record|toggle-record-window|toggle-record-region|
    toggle-pause|toggle-replay|replay-save|take-screenshot{,-region,-window}|status`.
    **Грабли**: портал ScreenCast демон проверяет только на старте — если он стартовал до установки
    `xdg-desktop-portal-gnome`, захват окна не работает; лечится
    `systemctl --user restart "app-gpu\x2dscreen\x2drecorder\x2dui@autostart.service"`.
  - **Виджет Noctalia «Screen Recorder»** — официальный плагин `screen-recorder` (v1.3.7, включён, стоит
    в правом блоке бара: `bar.widgets.right[].id = plugin:screen-recorder`): левый клик — старт/стоп,
    правый — настройки (`videoSource=portal` по умолчанию, fps, кодек, качество, аудио, replay,
    `restorePortalSession`, папка вывода), плюс виджет в Control Center. IPC:
    `noctalia msg plugin <author/plugin:entry> plugin:screen-recorder <event>`
    (toggle/start/stop/toggleReplay/saveReplay). **Не держать одновременно с gsr-ui**: оба запускают свой
    `gpu-screen-recorder`.
- **Запись отдельного ОКНА (например, окна VM)**: на Wayland и gsr, и плагин умеют это только через портал
  (`-w portal`), нужен `xdg-desktop-portal-gnome` (niri отдаёт окна в диалог портала; в
  `~/.config/xdg-desktop-portal/portals.conf` — `default=gnome` + gtk для Access/Notification/FileChooser).
  Поток приходит по PipeWire, размер кадра = размер окна.
  **Грабли (2026-10-16)**: gsr запрашивает `types=7` (монитор+окно+виртуальный), а niri реализует только
  `RecordMonitor`/`RecordWindow` (нет `RecordVirtual`), и «Virtual Monitor» в диалоге выбирается
  автоматически, т.к. niri отдаёт DisplayConfig без актуальной конфигурации
  (`Monitor 'Built-in display' has no configuration which is-current!`). При выборе этого пункта Start
  падает: `Unknown method 'RecordVirtual'`. Окно надо выбирать в разделе «Окна»/«Windows».
  Повторно то же окно без диалога: включить `restorePortalSession` / `-restore-portal-session yes` —
  gsr переиспользует restore-token `~/.config/gpu-screen-recorder/restore_token` (окно сопоставляется
  по app-id+title). Проверка в логе: `pipewire negotiation finished`.
- **Альтернативы с выбором источника**: `kooha` (extra, GTK4/libadwaita + портал, движок GStreamer),
  `gpu-screen-recorder-gtk` (AUR, GTK-фронтенд к тому же gsr), OBS Studio (`Mod+Shift+O`).
- **Возможные плюшки**: виджеты бара Noctalia `PrivacyWidget` (индикатор screen-sharing/mic/camera) и
  `CustomButtonWidget`; niri window-rule `match is-window-cast-target=true` с красным focus-ring
  (подсветка записываемого окна); пакет `gpu-screen-recorder-notification` (`gsr-notify`).
- **Куда пишет**: видео → `~/Videos/` (у Noctalia-плагина — папка из его настроек), replay-клипы;
  OBS Studio (32.2.2) установлен. Скриншоты: `Mod+Shift+S` — область в файл+буфер
  (`~/.config/scripts/screenshot_region_clipboard.sh`); у Noctalia свои — `noctalia msg screenshot-region`,
  `screenshot-fullscreen`, `screenshot-annotate`.

## Крышка ноутбука (archlinux-notebook)
- **Поведение**: крышка закрыта + зарядка (или внешний монитор) → система работает, встроенная
  матрица гаснет; крышка закрыта + батарея → сон (logind).
- **logind**: `/etc/systemd/logind.conf.d/10-lid.conf` — `HandleLidSwitch=suspend`,
  `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore`. Файл в dotfiles НЕ лежит
  (ставится руками с sudo).
  **Применять только `sudo systemctl reload systemd-logind`** — юнит `Type=notify-reload`, reload =
  SIGHUP, logind просто перечитывает конфиг (сессии/seat не трогает).
  **`restart` НЕЛЬЗЯ**: 2026-10-12 после `systemctl restart systemd-logind` живая сессия niri
  (запуск через lemurs) потеряла seat/DRM и сложилась в чёрный экран с TTY; при жёстком сбросе
  ext4 потеряла незафлашенный конфиг (файл остался 0 байт — проверять размер после установки!).
- **Матрица**: user-сервис `lid-display.service` (`~/.local/bin/lid-display`, оба файла в dotfiles,
  `WantedBy=graphical-session.target`). Слушает D-Bus logind (`LidClosed` + `PrepareForSleep`) и
  дёргает `niri msg output <выход> off/on`; внутренний выход ищет сам (`eDP*/LVDS*/DSI*`).
  Опции в юните: `LID_OUTPUT=eDP-1`, `LID_LOCK=1` (блокировать сессию при закрытии крышки — по
  умолчанию нет).
- **Грабли**: udev-правилом не сделать — `SW_LID` не генерирует uevent (в input core его нет),
  крышку обрабатывает только logind. `LidClosed` эмитится всегда, независимо от `HandleLidSwitch`;
  `OnExternalPower` изменений не эмитит, поэтому питание читается в момент события.
- Проверка: `systemctl --user status lid-display`, `journalctl --user -u lid-display -f`,
  `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed`;
  после reload у logind должно быть `HandleLidSwitch=suspend`, `HandleLidSwitchExternalPower=ignore`,
  `HandleLidSwitchDocked=ignore` (в журнале — `systemd-logind: Config file reloaded.`).

## NetBird MCP (machine management)
- Opencode has a built-in NetBird MCP tool (`netbird` MCP server).
- Requires `NETBIRD_API_KEY` env var (personal access token from NetBird dashboard).
- Available tools: `list-peers`, `get-peer`, `get-peer-by-ip`, `rename-peer`.
- **Secrets**: `NETBIRD_API_KEY` stored in `~/.config/zsh/secrets.zsh` (encrypted via chezmoi+age).
  Source before starting opencode: `source ~/.config/zsh/secrets.zsh`

## AmneziaWG / awgq (терминальный VPN-клиент)
- **`awgq`** — Python CLI/TUI (`~/projects/awgq`, symlink `~/.local/bin/awgq -> ~/projects/awgq/awgq.sh`, venv в `~/projects/awgq/.venv`). Раскатывается через dsync на весь флот; mesh = **NetBird**, `wt0`/table `7120` (Tailscale удалён со всех машин).
- Конфиги VPN: `/etc/amnezia/amneziawg/configs/` (активный — симлинк `/etc/amnezia/amneziawg/wg0.conf`). Конфиг awgq: `~/.config/awgq/config.yaml` (в chezmoi).
- **Команды**: `awgq on/off/toggle/restart` (systemd `awg-quick@wg0.service` + netbird-fix), `awgq config <имя>`, `awgq status`, `awgq netbird fix`, `awgq tui`. zsh-обёртка: `~/.config/zsh/functions/awg.zsh`.
- **Скорость/грабли (2026-10-06)**: `awgq on/off` — ~1 c (`VPNManager.wait_ready()` ждёт «юнит active + IPv4 на iface» вместо `sleep(2/5)`; `netbird status` (~1.4 c) в `status()` заменён чтением IP с интерфейса). В `netbird_manager.fix_routes()` **нельзя удалять ip-правила по одному префу**: `awg-quick` занимает низкие pref (`99/100`), которые пересекаются с legacy-списком `old_rule_prefs` (там есть `100`) — иначе сносится VPN-правило `suppress_prefixlength`, юнит остаётся `active`, а трафик идёт мимо wg0. Есть guard `_is_vpn_rule()`. Проверка: `ip route get 8.8.8.8` → `dev wg0 table 51820`, `ip route get 100.89.126.211` → `dev wt0 table 7120`.
- **Веб-панель** `awgq web` (Next.js + shadcn, `~/projects/awgq/web`): локальный сервер на `http://127.0.0.1:3131` — тумблер VPN, проверки (IP/гео/YouTube/ping/DNS/скорость), конфиги (добавить/переключить/удалить), автопоиск рабочего конфига с автоотключением. `awgq web` (= `up`) один раз спросит sudo, поставит правило `/etc/sudoers.d/awgq` (passwordless `ln -sf`/`cp`/`rm` строго в каталоге конфигов + `ip`/`systemctl`), поднимет сервер и включит systemd-user сервис `awgq-web.service` в автозапуск. Режимы: `up | run | install-service | down | status | logs`.
- **Раскатка на флот**: репозиторий `awgq` — явный проект dsync (`[projects.awgq]`), хаб клонит/пулит его на все машины; `post_pull = scripts/awgq-post-pull.sh` (создаёт venv, symlink `~/.local/bin/awgq`, ставит web-зависимости). После первого pull на машине — `awgq web up` (один раз).
- **Критично**: один конфиг = один ключ = **одно активное устройство одновременно** (у провайдера лимит до 5 устройств, но шарение одного ключа ведёт к «качелям»/лагам по всей сети). Для каждого устройства — свой конфиг/ключ. После разбора 2026-09-24: VPN на ноутах выключен (`disabled`), дом работает на Keenetic.
- **Пакеты**: `amneziawg-linux` (модуль ядра), `amneziawg-tools` (`awg-quick`), `amneziawg-go` (userspace, опционально). Нужен `openresolv` (иначе `resolvconf: command not found`).
