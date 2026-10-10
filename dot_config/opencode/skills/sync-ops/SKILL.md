---
name: Sync Ops
description: |
  Use when working with Syncthing or dsync: checking sync status, diagnosing
  "не синкается" / расхождений / конфликтов / офлайн-узлов, listing
  folders/devices, adding/renaming/pausing/removing folders, pushing/pulling
  dsync state. Triggers on: синхронизация, syncthing, dsync, статус синка,
  папки/шары, устройства синхронизации, кто к кому подключён, sync status,
  sync conflict, не синкается, расходится, офлайн узел.
  Topology facts are NOT in this skill — read the Obsidian vault note
  `🖥 servers/mesh-map.md` instead of assuming them.
---

# Sync Ops

Безопасные операции и диагностика Syncthing + dsync.

## Топология — читать, а не подразумевать

Этот скилл **намеренно не хранит адреса, ID устройств и состав шары** —
именно такие копии устаревают и начинают врать (раньше здесь был Tailscale,
снятый 2026-09-24). Источники правды, в порядке приоритета:

1. **Живой MCP `sync-ops`** — `st-list-devices`, `st-list-folders`,
   `st-connections`, `overview`. Это фактическое состояние прямо сейчас.
2. **Vault `🖥 servers/mesh-map.md`** — карта меша, роли машин, оверлеи,
   история изменений топологии. Обязательно читать перед разбором
   «кто к кому / что раздаёт».
3. `🖥 servers/ssh-aliases.md` — SSH-алиасы (ходят по NetBird IP).

Если MCP и mesh-map расходятся — **прав MCP**, а mesh-map надо обновить
(см. «Логирование»).

## Инструменты

- MCP `sync-ops` — основной интерфейс: `overview`, `st-*` (папки/устройства/
  соединения/мутации), `dsync-*` (status/doctor/push/pull).
- `scripts/syncthing-api.sh` — GET к локальному Syncthing REST из шелла,
  когда MCP недоступен (ключ подхватывает сам). См. `references/api-endpoints.md`.

Быстрая сводка всегда начинается с `overview`.

## Доктор: симптом → проверки → вердикт

Порядок жёсткий: сначала факты (read-only), потом гипотеза, и только потом
мутации. Никогда не мутировать, не показав картину.

### «Папка не синкается» / «расходится»

1. `overview` — есть ли папка, не `paused`, кто вообще `connected`.
2. `st-folder-status <id>` — `needBytes`, `errors`, `state`. Ненулевой
   `needBytes` + активный peer = просто идёт передача, не баг.
3. `st-completion <id>` — % по **каждому** устройству. Ключевой сигнал:
   у кого-то 100%, у кого-то 0% → проблема на стороне отстающего узла,
   а не в папке.
4. `st-connections` — по какому адресу соединение: LAN, NetBird или
   `relay://` (relay = медленно; объясняет «висит на 99%»).

Вердикт формулировать цифрами: «нужно 1.2 GB, идёт через relay, поэтому
медленно», а не «вроде синкается».

### «Локальные правки не уезжают»

1. `st-scan <id>` — форсировать скан (правки, сделанные вне Syncthing, иногда
   ждут следующего скана).
2. `overview` — папка не `paused`? **Paused останавливает синк и НЕ раздаёт
   локальные изменения** (см. `st-pause-folder`), при этом выглядит «живой».
3. `st-completion <id>` — у пира 0% при своих 100% → ждём отстающего, а не баг.

### «Устройство офлайн» / pull FAILED

1. `st-list-devices` — не `paused` ли (paused узла легко спутать с офлайном).
2. `st-connections` — `connected=false` и какой последний `address`.
3. `dsync-status` — у офлайн-узла будет `pull FAILED (No route to host)`.
   Это значит «машина выключена или не в NetBird», а НЕ сломанный dsync.
4. `ssh <алиас>` (по NetBird) + на той машине `st-status`.
5. `netbird` MCP `list-peers` — виден ли пир вообще.

Отличать: **выключенная машина** (норма, ничего не делать) от
**живой, но не подключённой к мешу** (настоящая проблема).

### dsync

1. `dsync-doctor` — по пунктам: `config`, `hub_connect`, `machine name`,
   `hub token`, `hub trust (TOFU)`, `ssh key`, `netbird route`, `projects`.
   Первая `✗` — причина.
2. `dsync-status` — кто `online`, у кого `pull ok` / `pull FAILED`, попытки.
3. Типовые диагнозы:
   - `✗ hub token` → на машине нет/не тот per-machine токен
     (`~/.config/dsync/dsync/tokens.toml`, 0600, не в git). Хаб отвергает →
     машина «offline» навсегда. Завести вручную из `[hub] tokens` на сервере.
   - `pull FAILED (No route to host)` → узел недоступен по NetBird/SSH.
   - `✗ netbird route` → интерфейс NetBird поднят, но маршрут до hub IP нет.
   - `push` не разносит `~/projects` → так и задумано: `[auto_projects]
     sync = false`, dsync только анонсирует состояния. Проекты — git+GitHub.

### Конфликты

- Ищи `*.sync-conflict-*` и `*conflicted copy*` в папке.
- **Не удалять конфликты молча** — показать список, дать пользователю выбрать
  версию, только потом чистить.
- Частый источник — `.stignore`, попавший в синк, или синк `.git`
  (анти-паттерн, см. п. «Подводные камни»).

## Безопасные операции (обязательные правила)

1. **Начинать с read-only** (`overview` / `st-status` + `st-connections`).
2. **Мутации** (`st-add-folder`, `st-update-folder`, `st-remove-folder`,
   `st-pause-folder`, `st-resume-folder`, `st-restart`) — только после явного
   подтверждения пользователем. `confirm="yes"` не подразумевать.
3. **Удаление папки**: `st-folder-status` → если папка shared — предложить
   `st-pause-folder` → и только потом `st-remove-folder` c `confirm="yes"`.
   Удаление **не трогает файлы на диске** — говорить это явно.
4. **Изменение шары / переименование** (`st-update-folder`) — предупредить о
   влиянии на остальные узлы меша.
5. **Добавление папки** (`st-add-folder`) — `shareWith` только по согласию
   пользователя; по умолчанию папка локальная.
6. **Не скрывать цифры**: `needBytes`, счётчики, офлайн-узлы. Сначала
   проблемы, потом «всё 100%».

## Подводные камни (проверено)

- **Syncthing v2**: `/rest/system/status` больше **не содержит** `version`,
  `folders`, `devices`. Версия — `/rest/system/version`; счётчики — по
  `/rest/config/{folders,devices}`. Код, читающий `status.version`, молча
  получает `undefined`.
- **PUT/DELETE в Syncthing REST отвечают 200 с ПУСТЫМ телом** — не парсить
  ответ как JSON.
- Конфиг применяется **асинхронно** — после add/update подождать 1–2 сек.
- GUI только `127.0.0.1:8384` на всех машинах → удалённый REST возможен лишь
  через ssh с самой машины или туннель; напрямую по NetBird/LAN нет.
  Ключ: `~/.local/state/syncthing/config.xml`, тег `<apikey>`.
- **Не синкать `.git`** (и вообще вложенные репозитории) — Syncthing рвёт
  объекты и генерирует тысячи конфликтов. Лечится `~/<folder>/.stignore`
  на **каждой** машине. В `.stignore` комментарий — только `//`, `#` НЕ
  является комментарием.
- **dsync не имеет подкоманд `sync`/`syncthing`** — только
  `init/hub/watch/push/capture/pull/trust/status/doctor/bot/tui`.
  Syncthing смотреть через `st-*`.
- **dsync пишет цветной tracing-лог**; MCP гасит его через `NO_COLOR=1` +
  стрип ANSI. Если править обёртку dsync — не потерять это.
- Меш **асимметричен**: набор устройств у локальной машины ≠ набор на хабе.
  «Все 5 устройств» видно только с хаба; локально — только свои шаренные.
  Поэтому топологию нельзя выводить из одного `st-list-devices`.

## Логирование

Значимые изменения (add/remove/rename папок, смена шары, разбор конфликтов)
фиксировать в vault: `🧠 opencode-memory/📜 sessions/YYYY-MM-DD-*.md`.
При изменении топологии (папки/устройства/оверлеи) — **обновлять
`🖥 servers/mesh-map.md`**, это рабочий документ меша.

## Вспомогательные файлы

- `scripts/syncthing-api.sh` — GET к локальному Syncthing REST.
- `references/api-endpoints.md` — шпаргалка по REST endpoint'ам.
