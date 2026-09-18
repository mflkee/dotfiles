---
name: Sync Ops
description: |
  Use when working with Syncthing or dsync: checking sync status, listing
  folders/devices, adding/renaming/pausing/removing folders, pushing/pulling
  dsync state. Triggers on: синхронизация, syncthing, dsync, статус синка,
  папки/шары, устройства синхронизации, кто к кому подключён, sync status.
  Topology facts are NOT in this skill — read the Obsidian vault note
  `obs_main/servers/mesh-map.md` instead of assuming them.
---

# Sync Ops

Безопасные операции с Syncthing и dsync в инфраструктуре пользователя.

## Топология — читать, а не подразумевать

- **Единственный источник по мешу**: vault `obs_main/servers/mesh-map.md`.
  Перед любым разбором «кто к кому / что раздаёт» — прочитать его.
- Кратко: ssh/dsync/Obsidian-REST ходят по **NetBird** (100.89.x.x); файловый
  слой Syncthing — `address=dynamic`, сейчас на **Tailscale** (IPv6 fd7a:...).
- Hub = `archlinux-server` (Syncthing-хаб + dsync QUIC UDP `0.0.0.0:42069`),
  dsync-клиенты ходят на NetBird IP `100.89.126.211:42069`.
- Syncthing GUI слушает только `127.0.0.1:8384`; REST-ключ —
  `~/.local/state/syncthing/config.xml` (`<apikey>`).

## Инструменты

- MCP `sync-ops` — основной интерфейс: `overview`, `st-*` (папки/устройства/
  соединения/мутации), `dsync-*` (status/doctor/push/pull).
- `scripts/syncthing-api.sh` — GET к локальному Syncthing REST из шелла,
  когда MCP недоступен (ключ подхватывает сам). См. `references/api-endpoints.md`.

## Безопасные операции (обязательные правила)

1. **Начинать с `overview`** (или `st-status` + `st-connections`) — увидеть
   картину ДО действий.
2. **Мутации** (`st-add-folder`, `st-update-folder`, `st-remove-folder`,
   `st-pause-folder`, `st-resume-folder`, `st-restart`) — только после явного
   подтверждения пользователем. `confirm="yes"` не подразумевать.
3. **Удаление папки**: сначала `st-folder-status` → если папка shared с
   другими узлами — предложить `st-pause-folder` → только потом
   `st-remove-folder` c `confirm="yes"`. Удаление НЕ трогает файлы на диске —
   говорить об этом явно.
4. **Переименование/изменение шары** (`st-update-folder`) — предупредить о
   влиянии на остальные машины меша.
5. **Добавление папки** (`st-add-folder`) — `shareWith` только по согласию
   пользователя, по умолчанию папка локальная.
6. Не скрывать цифры: `needBytes`, число фолдеров, офлайн-устройства — в
   ответе первым делом проблемы, потом «всё 100%».

## Чеклист «проверить состояние»

1. `overview` — папки, онлайн-устройства, dsync.
2. Если папка «застряла» — `st-folder-status <id>` (needBytes, errors).
3. `st-connections` — кто реально подключён и по какому адресу.
4. Нужен взгляд с другого узла — `ssh <алиас>` (идёт по NetBird) + тот же
   REST-ключ этой машины; алиасы см. `servers/ssh-aliases.md` в vault.
5. `dsync-status` / `dsync-doctor` — hub (QUIC) и машины.

## Подводные камни

- **PUT/DELETE в Syncthing REST возвращают 200 с ПУСТЫМ телом** — не парсить
  ответ как JSON (упадёт «Unexpected end of JSON input»).
- Конфиг применяется **асинхронно** — после add/update подождать 1–2 сек
  перед повторной проверкой.
- GUI на всех машинах только `127.0.0.1` — удалённый REST возможен только
  через ssh с самой машины или туннель; напрямую по NetBird/Tailscale нет.
- Меш асимметричен: **desktop отсутствует в меше mkair** — «все 5 устройств»
  с hub ≠ «все 5» с mkair; Documents не шарится на nova/notebook.
- `dsync` НЕ имеет подкоманд `sync`/`syncthing` — только
  `daemon/push/pull/status/doctor/bot/tui`; Syncthing смотреть через `st-*`.

## Логирование

Значимые изменения (добавление/удаление/переименование папок, смена шаров)
фиксировать в vault: заметка сессии `opencode-memory/sessions/YYYY-MM-DD-*.md`,
а при изменении топологии (папки/устройства/оверлеи) — обновлять
`servers/mesh-map.md` (это рабочий документ меша).

## Вспомогательные файлы

- `scripts/syncthing-api.sh` — GET-запрос к локальному Syncthing REST.
- `references/api-endpoints.md` — шпаргалка по REST endpoint'ам.