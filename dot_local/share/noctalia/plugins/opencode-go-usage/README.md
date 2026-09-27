# OpenCode Go Usage — виджет лимитов OpenCode Go для бара Noctalia

Показывает в баре лимиты подписки OpenCode Go: rolling 5h, weekly и monthly.
Тултип содержит все три значения и время до сброса.

## Откуда данные

Виджет зовёт тот же эндпоинт, что и веб-дашборд консоли:

```
GET https://opencode.ai/console/api/go/status
Authorization: Bearer <access_token>
x-org-id: <org_id>
```

Ответ — обычный JSON, без разбора HTML:

```json
{"access":{"endsAt":"2026-10-18T10:53:49.000Z","meters":{
  "fiveHour":{"resetsAt":null,"limitMicroCents":"1200000000","usedMicroCents":"0"},
  "week":{"resetsAt":"2026-09-28T00:00:00.000Z","limitMicroCents":"3000000000","usedMicroCents":"3000000000"},
  "month":{"limitMicroCents":"6000000000","usedMicroCents":"3000000000"}}}}
```

Счётчики — это не запросы, а лимиты расхода в микро-центах, поэтому процент
считается как `used / limit`. У `fiveHour` поля `resetsAt` нет, пока лимит не
начали тратить (это скользящее окно), у `month` сброса нет вовсе — там дата
продления из `access.endsAt`.

Ошибки отображаются так: `401`/`403` → ⚠ (токен отвергнут), прочее → !.

## Учётные данные

Токен **не** хранится в настройках Noctalia: `settings.toml` имеет права 0644.
Всё делает скрипт `~/.local/bin/opencode-go-auth` (тоже из chezmoi):

```bash
opencode-go-auth login    # OAuth device flow: открыть страницу, нажать Authorize
opencode-go-auth status   # те же цифры, что покажет виджет
opencode-go-auth logout   # удалить credentials.json
```

`login` кладёт в `~/.config/opencode-go/credentials.json` (каталог 0700, файл
0600) три поля:

```json
{
  "org_id": "wrk_…",
  "access_token": "…",
  "expires_at": 1793104191
}
```

Альтернатива — переменные окружения `OPENCODE_GO_ORG` и `OPENCODE_GO_TOKEN`
(имеют приоритет над файлом). Путь к файлу переопределяется в настройках
виджета (`credentials_file`).

### Токен живёт 30 дней

`login` выдаёт токен на 30 дней. Обновить его нечем: консоль принимает
`grant_type=refresh_token` для `client_id=opencode-cli`, но возвращает
access-токен, который все её же endpoints отбивают с `401`, при этом refresh-токен
сгорает. Так что единственный способ — снова прогнать `login`.

Чтобы это не превратилось в сюрприз, виджет за три дня до истечения красит себя
в жёлтый и пишет в тултипе подсказку. После истечения будет ⚠.

Плагинам Noctalia нельзя писать файлы, поэтому автообновление из виджета
невозможно — это осознанное ограничение, а не недоработка.

## Установка

Плагин лежит в `dot_local/share/noctalia/plugins/opencode-go-usage/`, chezmoi
разворачивает его в `~/.local/share/noctalia/plugins/opencode-go-usage/` —
это встроенный источник «local» Noctalia. Дальше:

1. `chezmoi apply`
2. В `~/.local/state/noctalia/settings.toml`:
   - `[plugins] enabled = [..., "mflkee/opencode-go-usage"]`
   - `[widget.oc-usage]` с `type = "mflkee/opencode-go-usage:usage"`
   - добавить `"oc-usage"` в `[bar.default].end`
3. Перезагрузить shell: `systemctl --user restart noctalia-shell.service`

Либо через UI: Settings → Plugins → OpenCode Go Usage → Enable, затем
Settings → Bar → добавить виджет.

## Управление

- Левый клик по виджету — принудительное обновление (с уведомлением).
- Средний клик — стандартно открывает настройки этого виджета.
- `noctalia msg plugin mflkee/opencode-go-usage:usage eDP-1 refresh` — обновить
  из терминала (можно повесить на биндинг niri).
- `display = "all"` в настройках виджета — показывать в баре все три лимита
  вместо самого загруженного (`worst`).

## Проверка изменений

```bash
noctalia plugins lint ~/.local/share/noctalia/plugins/opencode-go-usage/
lua5.4 /tmp/opencode/test_usage.lua   # 12 сценариев на стабах API
```
