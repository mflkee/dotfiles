# Syncthing REST API — шпаргалка

Базовый URL локально: `http://127.0.0.1:8384`, заголовок `X-API-Key: <ключ>`.
Ключ: env `SYNCTHING_API_KEY` или `<apikey>` из `~/.local/state/syncthing/config.xml`.

## Чтение (GET)

| Endpoint | Что даёт |
|----------|----------|
| `/rest/system/status` | myID, версия, uptime, юзеры |
| `/rest/system/connections` | по каждому deviceID: connected, address, in/out bytes |
| `/rest/config/folders` | все папки с `devices` (с кем shared) |
| `/rest/config/devices` | все устройства (deviceID, name, addressed) |
| `/rest/db/status?folder=<id>` | состояние папки (needBytes, errors, state) |
| `/rest/db/completion?folder=<id>` | прогресс по папке |
| `/rest/events?since=…` | события |

## Мутации (PUT/DELETE) — только через MCP sync-ops

| Endpoint | Метод | Назначение |
|----------|-------|------------|
| `/rest/config/folders` | PUT | добавить/заменить папку |
| `/rest/config/folders/{id}` | PUT | обновить конкретную папку |
| `/rest/config/folders/{id}` | DELETE | удалить папку |
| `/rest/config/scan` | POST | запустить сканирование |

Важно: **PUT/DELETE возвращают 200 с пустым телом** — не парсить как JSON.
Конфиг применяется **асинхронно** — подождать 1–2 сек перед проверкой.

## Устройства меша (на дату карты, точнее — см. vault `servers/mesh-map.md`)

| Короткий ID | Машина |
|-------------|--------|
| QX6QAG5 | archlinux-server (hub) |
| MWBTMTZ | archlinux-mkair |
| 3WAB5DG | archlinux-desktop |
| SAAGLVR | archlinux-notebook |
| KYVIPWB | huawei-nova |

## Пример

```bash
scripts/syncthing-api.sh /rest/system/status
scripts/syncthing-api.sh /rest/system/connections
```