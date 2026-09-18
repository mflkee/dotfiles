---
name: Recipe Save
description: |
  Use after solving a hard / long problem to save the working approach as a
  reusable OpenCode skill. Manual invocation: "сохрани как скилл", "запиши
  рецепт", "сохрани решение", "зафиксируй как скилл", "сделай скилл из этой
  возни", "debrief и сохрани". Debriefs the session, generates a SKILL.md with
  steps, scripts, references and logging, and installs it globally or in the
  current project. Triggers on: recipe, skill, скилл, рецепт, сохрани как
  скилл, зафиксируй решение, debrief, lesson learned, подводные камни.
---

# Recipe Save

Превращает «час мучений + найденное решение» в переиспользуемый скилл.
Вызывается **вручную**, после того как задача решена и результат подтверждён.

## Схема работы

1. **Дебрифинг** — выяснить у пользователя (или из контекста сессии):
   задача, что НЕ сработало, что СРАЗУ сработало (точные команды/конфиги),
   какие файлы/документы помогли (пути).
2. **Параметры** — `id`, `scope`, `trigger` (см. таблицу ниже).
3. **Генерация** — `scripts/scaffold.sh` (или вручную по шаблону).
4. **Наполнение** — этапы, команды, вспомогательные файлы в `scripts/` и
   `references/`, логирование, подводные камни.
5. **Проверка и установка** — уникальный ID, заполненная description,
   исполняемые скрипты; для `global` — `chezmoi add`, чтобы скилл попал в
   dotfiles (см. «Установка global»).
6. **Лог** — скрипт сам пишет запись о создании.

## Параметры

| Параметр | Значения |
|----------|----------|
| `id` | kebab-case ascii, 1–64 символа, **уникальный** (ID = имя папки, не `name`) |
| `scope` | `global` → `~/.config/opencode/skills/<id>/`; `project` → `.opencode/skills/<id>/` от корня текущего проекта |
| `trigger` | `manual` → загрузка только по ID или слэш-команде (`autoinvoke: false`); `auto` → модель сама предлагает по `description` |

`scope` выбирается: `global` — если рецепт пригодится в других проектах;
`project` — если только внутри текущего. `trigger` — по умолчанию `manual`
(скилл и так редко нужен чаще двух раз).

## Команда

```bash
"$(dirname "$SKILL_BASE")/recipe-save/scripts/scaffold.sh" \
  --id <kebab-id> \
  --scope global|project \
  --trigger auto|manual \
  --name "Display Name" \
  --description "когда применять" \
  [--project <корень проекта; по умолчанию текущая папка>]
```

`$SKILL_BASE` — папка загруженного скилла. Если скрипт недоступен — создать
файлы вручную по шаблону ниже (не менять имя файла: обязательно `SKILL.md`).

## Шаблон создаваемого скилла

```markdown
---
name: <Название>
description: <одной строкой: когда применять этот рецепт>
trigger: manual|auto
created: YYYY-MM-DD
slash: true                                   # только для manual
metadata:
  opencode/autoinvoke: false                  # для manual; для auto — true/опустить
---

# <Название>

## Задача
Что решаем (1–3 строки).

## Этапы
1. Только то, что СРАЗУ сработало, в рабочем порядке.
2. …

## Команды и конфиги
Точные команды, готовые куски кода, конфиги.

## Вспомогательные файлы
- `scripts/…` — рабочие скрипты
- `references/…` — доки, выжимки, полезные пути

## Логирование
Выполнение скриптов рецепта пишет лог в:
`<корень проекта>/.opencode/recipe-logs/<id>/run.log` (project)
`~/.local/share/opencode/recipe-logs/<id>/run.log` (global)

## Подводные камни
- Что НЕ пробовать — экономит час в следующий раз.
```

## Установка global (chezmoi)

`~/.config/opencode` управляется chezmoi (источник `~/dotfiles/dot_config/opencode`).
После генерации глобального скилла:

```bash
chezmoi add ~/.config/opencode/skills/<id>
```

(или создать файлы сразу в `~/dotfiles/dot_config/opencode/skills/<id>/` и
выполнить `chezmoi apply`). Проектные скиллы пишутся напрямую в `.opencode/skills/`
проекта, chezmoi не нужен.

## Правила

- **Скилл = стабильный рецепт.** Переменный контекст (состояние проектов,
  текущие задачи) — не сюда, это Obsidian (`opencode-memory`).
- Создавать скилл только если задача реально повторится; иначе это мусор.
- Если похожий скилл уже существует — дополнить его, а не плодить дубликаты
  с другим ID (перекроется по ID с приоритетом project > global).
- `description` обязательна и однозначна: без неё модель не увидит скилл;
  расплывчатая — будет дёргать скилл не к месту.
- `name` можно на русском, `id` — строго kebab-case ascii.