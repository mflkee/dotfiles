# awgq VPN — виджет бара Noctalia

Виджет [Noctalia](https://noctalia.dev) v5 для управления AmneziaWG из бара:
показывает состояние туннеля `awg-quick@wg0.service`, активный конфиг и
внутренний IP.

## Поведение

| Действие | Что делает |
|----------|-----------|
| Левый клик | `awgq toggle` — поднять/опустить VPN (вместе с netbird-fix) |
| Правый клик | Сводка (статус · конфиг · IP) во всплывающем уведомлении |
| Средний клик | Настройки виджета (встроенное поведение Noctalia) |

Индикация: `shield-lock` зелёный — включён, `shield-off` приглушённый —
выключен, `loader` — переключение.

IPC (для хоткеев/скриптов):

```sh
noctalia msg plugin mflkee/awgq:vpn focused toggle
noctalia msg plugin mflkee/awgq:vpn focused on
noctalia msg plugin mflkee/awgq:vpn focused off
noctalia msg plugin mflkee/awgq:vpn focused refresh
```

## Откуда данные

Статус читается дешёвыми командами, без запуска `awgq status` (тот грузит
Python ~1 c):

```sh
systemctl is-active awg-quick@wg0.service   # active/inactive
readlink -f /etc/amnezia/amneziawg/wg0.conf # активный конфиг
ip -4 -o addr show dev wg0                  # внутренний IP
```

Тогл идёт через `awgq`, потому что он дополнительно применяет маршруты NetBird
(`awgq netbird fix`). Права: `/etc/sudoers.d/awgq` (passwordless
`systemctl ... awg-quick@wg0.service`).

## Установка

Локальный плагин лежит в `~/.local/share/noctalia/plugins/awgq/` (в chezmoi —
`dot_local/share/noctalia/plugins/awgq/`). Включается в конфиге Noctalia:

```toml
[plugins]
enabled = [ "mflkee/awgq" ]

[bar.default]
end = [ "network", "awgq" ]

[widget.awgq]
type = "mflkee/awgq:vpn"
```

GUI-оверрайды в `~/.local/state/noctalia/settings.toml` имеют приоритет над
`~/.config/noctalia/config.toml` — если виджета нет в баре, проверь, не задан ли
`[bar.default]` в state-файле.
