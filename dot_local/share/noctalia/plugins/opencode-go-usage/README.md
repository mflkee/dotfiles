# OpenCode Go Usage — виджет лимитов OpenCode Go для бара Noctalia

Показывает в баре лимиты подписки OpenCode Go: rolling 5h, weekly и monthly.
Тултип содержит все три значения и время до сброса.

## Откуда данные

Официального API для лимитов нет (только feature request), поэтому виджет
читает ту же страницу, что и CLI-тул `opencode-go-usage-analyzer`:

```
GET https://opencode.ai/workspace/<workspace_id>/go
Cookie: auth=<token>; oc_locale=en
```

Номера лежат в HTML в блоке `<div data-slot="usage">`; теги вырезаются, дальше
разбираются три маркера `Rolling Usage` / `Weekly Usage` / `Monthly Usage`.

Если в ответе есть `Continue with Google` — токен не принят (виджет покажет ⚠).

## Учётные данные

Токен **не** хранится в настройках Noctalia: `settings.toml` имеет права 0644.
Он лежит в отдельном файле с правами 0600:

```bash
mkdir -p ~/.config/opencode-go && chmod 700 ~/.config/opencode-go
$EDITOR ~/.config/opencode-go/credentials.json   # chmod 600
```

```json
{
  "workspace_id": "…",
  "token": "…"
}
```

Как получить: открыть <https://opencode.ai/workspace/…/go> в браузере, войти,
 затем devtools → Application → Cookies → `opencode.ai` → значение `auth`.
`workspace_id` — это идентификатор в URL после `/workspace/`.

Альтернатива — переменные окружения `OPENCODE_GO_WORKSPACE` и
`OPENCODE_GO_TOKEN` (имеют приоритет над файлом).

Файл можно переопределить в настройках виджета (`credentials_file`).

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
- `noctalia msg plugin mflkee/opencode-go-usage:usage refresh` — обновить
  из терминала (можно повесить на биндинг niri).
