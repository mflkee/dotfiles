# Syncthing REST API — шпаргалка

Базовый URL локально: `http://127.0.0.1:8384`, заголовок `X-API-Key: <ключ>`.
Ключ: env `SYNCTHING_API_KEY` или `<apikey>` из `~/.local/state/syncthing/config.xml`.
GUI слушает только `127.0.0.1` — с удалённой машины либо `ssh`, либо туннель.

## Чтение (GET)

| Endpoint | Что даёт |
|----------|----------|
| `/rest/system/status` | myID, uptime, goroutines, discoveryEnabled ⚠️ **без** version/folders/devices (v2) |
| `/rest/system/version` | `version`, `longVersion`, `os/arch`, `codename` |
| `/rest/system/connections` | по каждому deviceID: connected, address, in/out bytes |
| `/rest/config/folders` | все папки с `devices` (с кем shared) |
| `/rest/config/devices` | все устройства (deviceID, name, addresses) |
| `/rest/db/status?folder=<id>` | состояние папки (needBytes, errors, state) |
| `/rest/db/completion?folder=<id>&device=<id>` | прогресс по папке для устройства |
| `/rest/events?since=…` | события |

## Мутации (PUT/DELETE) — только через MCP sync-ops

| Endpoint | Метод | Назначение |
|----------|-------|------------|
| `/rest/config/folders` | PUT | добавить/заменить папку |
| `/rest/config/folders/{id}` | PUT | обновить конкретную папку |
| `/rest/config/folders/{id}` | DELETE | удалить папку |
| `/rest/config/scan` | POST | запустить сканирование |

Важно: **PUT/DELETE отвечают 200 с пустым телом** — не парсить как JSON.
Конфиг применяется **асинхронно** — подождать 1–2 сек перед проверкой.

## Устройства меша

**Список здесь не хранить** — он разный у каждого узла (меш асимметричен) и
меняется. Живой источник: MCP `sync-ops` → `st-list-devices`, либо:

```bash
scripts/syncthing-api.sh /rest/config/devices
```

Кто есть в меше и как связан — vault `🖥 servers/mesh-map.md`.

## Пример

```bash
scripts/syncthing-api.sh /rest/system/version
scripts/syncthing-api.sh /rest/system/connections
```
