---
name: home-cleanup
description: |
  Use when the user asks to clean up / tidy the home directory (~), organize or
  distribute files into proper folders, declutter, refactor the home layout, or when
  stray files / projects / directories appeared at $HOME root.
  Invoke manually: "уберись в домашней папке", "наведи порядок в ~", "разложи по папкам",
  "home cleanup", "declutter home", "tidy up $HOME".
  Triggers on: уборка, порядок, структуризация, захламление, домашняя папка,
  home, cleanup, tidy, declutter, organize files.
---

# Home Cleanup Skill

Целевая машина: любой хост из mesh (desktop, notebook, archlinux-mkair,
archlinux-server). Сначала определи машину: `hostname`.

Этот SKILL.md живёт в chezmoi-репозитории (`~/dotfiles/...`) и синхронизируется
на все машины через dsync (git push → hub → pull + `chezmoi apply`). Правки —
только через source, никогда в live-копии.

## Целевая структура ~ (эталон)

| Путь | Назначение |
|------|-----------|
| `~/projects/` | ТВОИ кодовые проекты (git-репы, dsync-проекты); чужие клоны — в `~/tools/` |
| `~/tools/` | Сторонние утилиты / vendor-клоны (напр. `keenetic-antifilter` — качается ради `routes/` для Keenetic-роутера) |
| `~/keebs/` | Клавиатурное: прошивки (`.uf2`), раскладки (VIA `.vil`) — ErgoHaven и др. |
| `~/Documents/reports/` | Отчёты (xlsx/zip/pdf отчёты о работах) |
| `~/Documents/` | Документы, черновики (syncthing-корень — см. ограничения) |
| `~/Downloads/` | Только свежие загрузки; музыка → `~/Music/`, отчёты → `~/Documents/reports/` |
| `~/Music/`, `~/Pictures/`, `~/Videos/` | Медиа по XDG |
| `~/obs_main/` | Obsidian-хранилище (Syncthing-корень) |
| `~/esp/`, `~/esp32-backups/`, `~/.espressif/`, `~/.espup/`, `~/export-esp.sh` | ESP32 тулчейн (export-esp.sh — стандарт espup, НЕ удалять). EH/**не** esp32 — это ErgoHaven-клавиатура → `~/keebs/` |
| `~/go/` | GOPATH (GOPATH/pkg) |
| `~/nas/`, `~/mnt/`, `~/Menu/`, `~/apps/` | Точки монтирования / root-owned — НЕ трогать |
| `~/dotfiles/` | chezmoi source repo |
| `~/SETUP.md`, `~/AGENTS.md` | chezmoi-managed — не удалять вручную |

## Критичные ограничения (проверять ДОЛЖНОСТЬ)

### 1. Syncthing-корни
Проверь `~/.local/state/syncthing/config.xml` (или REST API:
`curl -H "X-API-Key: $KEY" http://127.0.0.1:8384/rest/config/folders`, ключ — из
`config.xml` `<apikey>`).

Известные корни: `obs_main`, `books`, `buffer`, `Documents`.

- **Перенос/переименование корня Syncthing = потеря данных на других машинах**
  (папка «опустеет» и удалится удалённо).
- **НЕЛЬЗЯ вкладывать syncthing-корень внутрь другого syncthing-корня**
  (напр. `~/Documents/books` — Documents тоже корень → конфликт вложенности).
- Легальный перенос корня: `POST /rest/config/folders/{id}` с новым `path` +
  `POST /rest/system/restart` (id и devices папки сохраняются).
- В остальном — либо не трогать, либо явно спросить пользователя.

### 2. chezmoi-managed файлы
- Source of truth: `~/dotfiles/`. Managed пути (проверка: `chezmoi managed | grep <path>`)
  — `~/.zshrc`, `~/.zshenv`, `~/.tmux.conf`, `~/.config/*` (все, что есть в dotfiles).
- Если надо поправить managed-файл: `chezmoi edit <target> --apply` или правка
  source-файла в `~/dotfiles/` + `chezmoi apply`.
- Не редактировать live-файлы напрямую при наличии source.
- После изменения dotfiles: `cd ~/dotfiles && git add -A && git commit -m "..." && git push`
  (это развезёт изменения по всем машинам через dsync).

### 3. Точки монтирования и чужие каталоги
`nas` (rclone fuse), `mnt/phone`, `Menu`, `apps` (root-owned) — не двигать, не удалять.

### 4. Работающие процессы
Перед переносом объёмных данных проверь, не использует ли кто-то файлы
(`lsof` / `fuser` при сомнении).

## Workflow

1. **Инвентаризация**
   - `ls -la ~` и `ls -1 ~`
   - `du -sh` подозрительных каталогов (большие — медленно, используй timeout)
   - Отметь: файлы в корне, проекты вне `~/projects/`, дубликаты, старые бэкапы,
     zcompdump с чужих хостов, пустые папки, «лишние» XDG.

2. **Проверка ограничений** (по разделу выше): syncthing-корни, chezmoi-managed,
   монтирования, работающие процессы.

3. **План + подтверждение**
   - Покажи пользователю таблицу «что → куда → почему».
   - На удаление и на перенос syncthing-корней / данных >100MB — обязательно
     подтверждение (вопрос с вариантами).
   - Музыка/отчёты из Downloads, пустые `.tmp_*`, старые `.zshrc.bak*`,
     `.zcompdump.<другой-хост>` — можно предлагать удалить, но всё равно спросить.

4. **Выполнение**
   - Переносы: `mv` (не `cp`!) — та же ФС, мгновенно.
   - Каталоги: проверить отсутствие конфликта цели (`[ ! -e target ]`).
   - Создавать цели `mkdir -p` по XDG.
   - Сомнительные файлы — в `~/.local/share/Trash/` вместо `rm`.

5. **Верификация**
   - Повторный `ls -1 ~` — корень должен содержать только XDG, монтирования,
     syncthing-корни, dotfiles и тулчейны.
   - `curl .../rest/db/status?folder=<id>` — папки в состоянии `idle`, needBytes=0.
   - `dsync status` — проекты в норме.

## Известные паттерны захламления (чек-лист)

- [ ] Свой код-проект в корне `~` → `~/projects/<name>/`; чужой клон/утилита → `~/tools/<name>/`
- [ ] Клавиатурные прошивки (`.uf2`) / раскладки (`.vil`) в корне или esp32-backups → `~/keebs/<brand>/`
- [ ] Отчёты (`report_*`, `interim_report_*`, `Отчет*.pdf`) → `~/Documents/reports/`
- [ ] mp3/музыка в `~/Downloads/` → `~/Music/`
- [ ] `.zshrc.bak*`, `.bashrc.bak*` → подтвердить и удалить
- [ ] `.zcompdump.<host>` со старых машин → удалить (свежий `.zcompdump` оставить)
- [ ] `*.log` в корне → удалить/переместить в `~/.cache/`
- [ ] Дубликаты systemd-юнитов в корне (`vpntel.service` и пр.) → удалить, если
      копия живёт в `~/projects/` или ставится через dotfiles
- [ ] Пустые `~/Projects` и прочие XDG-дубликаты → удалить/переписать `user-dirs.dirs`
- [ ] `xp_activate32.exe` и прочий подозрительный софт → спросить, обычно в trash
- [ ] Пустые `.tmp_*` в Downloads → удалить

## Шпаргалка

```bash
# Syncthing REST
KEY=$(grep -o '<apikey>[^<]*</apikey>' ~/.local/state/syncthing/config.xml | sed 's/<[^>]*>//g')
curl -H "X-API-Key: $KEY" http://127.0.0.1:8384/rest/config/folders        # список папок
curl -H "X-API-Key: $KEY" "http://127.0.0.1:8384/rest/db/status?folder=<id>"

# Chezmoi
chezmoi managed | grep <path>     # managed ли файл
chezmoi apply                     # применить source → live

# Dsync
dsync status; dsync pull
```