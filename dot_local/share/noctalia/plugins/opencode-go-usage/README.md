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
В репозитории он лежит в одном-единственном месте — в зашифрованном
`~/.config/zsh/secrets.zsh` (chezmoi + age), поэтому dsync разносит его сам на
все машины. Всё делает скрипт `~/.local/bin/opencode-go-auth` (тоже из chezmoi):

```bash
opencode-go-auth login    # OAuth device flow: открыть страницу, нажать Authorize
opencode-go-auth status   # те же цифры, что покажет виджет
opencode-go-auth sync     # перезаписать блок в secrets.zsh из credentials.json
opencode-go-auth logout   # удалить credentials.json и вычистить токен из secrets.zsh
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

### Как токен попадает в репозиторий

`login`/`logout`/`sync` переписывают управляемый блок прямо в
`~/.config/zsh/secrets.zsh` и не трогают ничего за его пределами:

```sh
# >>> opencode-go-auth >>>
export OPENCODE_GO_ORG="wrk_…"
export OPENCODE_GO_TOKEN="…"
export OPENCODE_GO_EXPIRES_AT="1793104191"
# <<< opencode-go-auth <<<
```

Дальше `chezmoi re-add` зашифровывает файл в `~/dotfiles`, а `dsync push`
разносит по остальным машинам. Значения с символами вне `[A-Za-z0-9_.:-]`
не записываются вовсе — файл этот sourced каждым шеллом.

Обратно на каждой машине credentials.json появляется сам: chezmoi-скрипт
`run_after_write-opencode-go-credentials.sh` после каждого `chezmoi apply`
(а dsync вызывает его после pull) раскладывает те же три значения в
`~/.config/opencode-go/credentials.json`, 0600, и молчит, если файл уже
актуален. То есть вручную ничего копировать не нужно — `chezmoi apply` и всё.

### Токен живёт 30 дней

`login` выдаёт токен на 30 дней. Обновить его нечем: консоль принимает
`grant_type=refresh_token` для `client_id=opencode-cli`, но возвращает
access-токен, который все её же endpoints отбивают с `401`, при этом refresh-токен
сгорает. Так что единственный способ — снова прогнать `login`.

Чтобы это не превратилось в сюрприз, виджет за три дня до истечения красит себя
в жёлтый и пишет в тултипе подсказку. После истечения будет ⚠.

Плагинам Noctalia нельзя писать файлы, поэтому автообновление из виджета
невозможно — это осознанное ограничение, а не недоработка.

## Несколько машин

Из живого на каждой машине нужно только одно — бар. Остальное приезжает само.

**Креды** лежат в зашифрованном `secrets.zsh`, его разносит dsync, а
chezmoi-скрипт после каждого apply раскладывает `credentials.json`. Ничего
копировать руками не нужно.

**Бар.** `~/.local/state/noctalia/settings.toml` chezmoi не управляет (у каждой
машины свой бар и свой набор мониторов), поэтому три строки из раздела
«Установка» дописываются на каждой машине руками — один раз.

Токен device flow не привязан к хосту, так что один токен на все машины, и
через 30 дней он истекает везде одновременно: предупреждение останется жёлтым
на всех машинах сразу. Продление — одна команда на любой машине:

```bash
opencode-go-auth login    # перезаписать токен, разнесётся сам
```

## Установка

Плагин лежит в `dot_local/share/noctalia/plugins/opencode-go-usage/`, chezmoi
разворачивает его в `~/.local/share/noctalia/plugins/opencode-go-usage/` —
это встроенный источник «local» Noctalia. Дальше:

1. `chezmoi apply` — приедет плагин, скрипт и (если токен уже есть в
   `secrets.zsh`) `credentials.json`
2. В `~/.local/state/noctalia/settings.toml`:
   - `[plugins] enabled = [..., "mflkee/opencode-go-usage"]`
   - `[widget.oc-usage]` с `type = "mflkee/opencode-go-usage:usage"`
   - добавить `"oc-usage"` в `[bar.default].end` (или `.start`, если виджет
     нужен слева)
3. Готово: Noctalia следит за `settings.toml` и подхватывает изменения сама
   (в логе — `config changed, reloading` и `loaded plugin 'mflkee/opencode-go-usage'`).
   Перезапуск шелла нужен только если плагин так и не появился.

Если виджет показывает ⚙ — нет `credentials.json`. На новой машине: разово
прогнать `opencode-go-auth login` (он и в secrets.zsh запишет, и разнесёт), на
существующей достаточно `chezmoi apply`.

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
