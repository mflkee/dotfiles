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

Этот SKILL.md живёт в chezmoi-репозитории
(`~/dotfiles/dot_config/opencode/skills/home-cleanup/SKILL.md`) и синхронизируется
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
| `~/Music/`, `~/Pictures/`, `~/Videos/` | Медиа по XDG (⚠️ `~/Pictures/` — chezmoi-managed дерево, см. ограничение 2) |
| `~/obs_main/` | Obsidian-хранилище (Syncthing-корень) |
| `~/esp/`, `~/esp32-backups/`, `~/.espressif/`, `~/.espup/`, `~/export-esp.sh` | ESP32 тулчейн (export-esp.sh — стандарт espup, НЕ удалять). EH/**не** esp32 — это ErgoHaven-клавиатура → `~/keebs/` |
| `~/Arduino/` | Arduino sketchbook (IDE/arduino-cli) — тулчейн, НЕ мусор (esp32-флиппер и пр. могут жить здесь) |
| `~/go/` | GOPATH (GOPATH/pkg) |
| `~/nas/`, `~/mnt/`, `~/Menu/`, `~/apps/`, `~/SynologyDrive/` | Точки монтирования / root-owned — НЕ трогать |
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

### 2. chezmoi-managed файлы (проверять КАЖДЫЙ кандидат!)
- Source of truth: `~/dotfiles/`. Managed-пути — это НЕ только `~/.zshrc`,
  `~/.zshenv`, `~/.tmux.conf` и `~/.config/*`, но и **целые деревья**: `~/Pictures/`
  (включая вложенные файлы — напр. `Pictures/Без имени 1.odt` это curated-файл, а не
  мусор!), тест-харнессы `~/test_*.sh` в корне и т.п.
- Перед переносом/удалением ЛЮБОГО файла — точная проверка конкретного пути:
  `chezmoi managed | grep -Fx '<путь-относительно-~>'`
  (напр. `Pictures/Без имени 1.odt`). Подстрочный `grep <path>` ловит лишнее;
  `-Fx` — только точное совпадение.
- Если надо поправить managed-файл: `chezmoi edit <target> --apply` или правка
  source-файла в `~/dotfiles/` + `chezmoi apply`.
- Не редактировать live-файлы напрямую при наличии source.
- **`chezmoi apply` НЕ удаляет «осиротевшие» цели** (файл, ставший unmanaged через
  `.chezmoiignore` или удалённый из source) — он остаётся в live. После проверки,
  что live-копия идентична source (`diff -q`), её убирают вручную в trash.
- **`chezmoi apply` может упереться в TTY-промпт** («X has changed since chezmoi
  last wrote it?») и упасть с `could not open a new TTY` в неинтерактивной сессии.
  Сначала `chezmoi diff`; если промпт про конкретный файл — верни его на место /
  разберись, прежде чем продолжать.
- После изменения dotfiles: `cd ~/dotfiles && git add -A && git commit -m "..." && git push`
  (это развезёт изменения по всем машинам через dsync).

### 3. Точки монтирования и чужие каталоги
`nas` (rclone fuse), `mnt/phone`, `Menu`, `apps`, `SynologyDrive` (root-owned) —
не двигать, не удалять.
- Перед удалением каталога убедись, что это не mountpoint:
  `mountpoint <dir>` / `findmnt -T <dir>`.
- Пустой root-owned каталог можно удалить **без sudo**, если ты владеешь родителем
  (`~`): удаление требует прав на запись в родительский каталог, а не в сам каталог.
  Пример: `rmdir ~/reports` (root-owned, пустой) сработало без sudo.

### 4. Работающие процессы
Перед переносом объёмных данных проверь, не использует ли кто-то файлы
(`lsof` / `fuser` при сомнении).

## Workflow

1. **Инвентаризация**
   - `ls -la ~` и `ls -1 ~`
   - `du -sh` подозрительных каталогов (большие — медленно, используй timeout)
   - Отметь: файлы в корне, проекты вне `~/projects/`, дубликаты, старые бэкапы,
     zcompdump с чужих хостов, пустые папки, «лишние» XDG.
   - По большим деревьям (`~/projects`) ищи через ripgrep (`rg`), а не `grep -r` —
     последний таймаутится на `.git`/`node_modules`/venv.

2. **Проверка ограничений** (по разделу выше): syncthing-корни, chezmoi-managed
   (по КАЖДОМУ кандидату, `chezmoi managed | grep -Fx`), монтирования, процессы.
   Дополнительно: `grep -n '\$HOME/"' ~/.config/user-dirs.dirs` — если XDG-каталоги
   схлопнуты в `$HOME/`, это прямой источник захламления корня (лечится в шаге 4).

3. **План + подтверждение**
   - Покажи пользователю таблицу «что → куда → почему».
   - На удаление и на перенос syncthing-корней / данных >100MB — обязательно
     подтверждение (вопрос с вариантами).
   - Музыка/отчёты из Downloads, пустые `.tmp_*`, старые `.zshrc.bak*`,
     `.zcompdump.<другой-хост>` — можно предлагать удалить, но всё равно спросить.

4. **Выполнение**
   - Переносы: `mv` (не `cp`!) — та же ФС, мгновенно.
   - Каталоги: проверить отсутствие конфликта цели (`[ ! -e target ]`).
   - Создавать цели `mkdir -p` по XDG. Если `~/.config/user-dirs.dirs` схлопнут в
     `$HOME/` — починить (`XDG_MUSIC_DIR="$HOME/Music"`, `TEMPLATES`/`PUBLICSHARE` →
     подкаталоги, `PROJECTS` → `$HOME/projects`) и **создать** каталоги `mkdir -p`.
   - Сомнительные файлы — в **актуальный trash этой машины** (`ls -d ~/.trash
     ~/.local/share/Trash`, НЕ хардкодь путь; на флоте это `~/.trash`) вместо `rm`.
     - В trash могут лежать read-only деревья (Go module cache ставит `0555`):
       `rm -rf` падает с Permission denied → сначала `chmod -R u+w <dir>`, потом `rm -rf`.

5. **Верификация**
   - Повторный `ls -1 ~` — корень должен содержать только XDG, монтирования,
     syncthing-корни, dotfiles и тулчейны.
   - `curl .../rest/db/status?folder=<id>` — папки в состоянии `idle`, needBytes=0.
   - `chezmoi diff` — чисто (нет неожиданных изменений после правок).
   - `dsync status` — проекты в норме.

## Закрытые проекты (не реанимировать без явной просьбы)

- **Кинотеатр (Jellyfin-стек)** — закрыт 2026-09-29 (сервер: все контейнеры/образы/юниты/
  скрипты сняты, loop-образ 200 ГБ удалён, VM `redos` остановлена). Архив конфигов для
  возможного восстановления: `/srv/kinoteatr-archive/kinoteatr-20260929-*.tar.gz`.
  Остатки на машинах подлежат удалению (см. чек-лист ниже).
- Если появляется «мусор» от других закрытых проектов — фиксировать здесь же.

## Известные паттерны захламления (чек-лист)

- [ ] Остатки закрытого кинотеатра: `qbittorrent-nox` (сервис+пакет),
      `~/.local/bin/media-drop`, `~/Downloads/kinoteatr`/`~/Downloads/euphoria-s2`,
      no-sleep override `/etc/systemd/logind.conf.d/10-nosleep.conf` (отменён на notebook,
      desktop ещё не дочищен — он был недоступен 2026-09-29), скрипты `dograb`/`media-*`
      (напр. в `/tmp`, `/usr/local/sbin`) → удалить
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
- [ ] XDG-каталоги, схлопнутые в `$HOME/` (`XDG_MUSIC_DIR="$HOME/"` и т.п.) → починить
      `~/.config/user-dirs.dirs`, создать `~/Music` и др. (иначе приложения пишут в корень)
- [ ] Свободные отладочные скриншоты/PNG в корне `~` (напр. `awgq-web*.png`) →
      `~/Pictures/Screenshots/`
- [ ] Тест-харнессы/дубликаты, задеплоенные в корень `~` (chezmoi-managed, но должны
      жить в repo) → перенести в repo, добавить имя в `.chezmoiignore`, live-копию — в trash
- [ ] `~/.backups/` — разовые pre-scrub git-бандлы (`*_pre_scrub_*.bundle`) → trash
- [ ] `xp_activate32.exe` и прочий подозрительный софт → спросить, обычно в trash
- [ ] Пустые `.tmp_*` в Downloads → удалить

## Шпаргалка

```bash
# Syncthing REST
KEY=$(grep -o '<apikey>[^<]*</apikey>' ~/.local/state/syncthing/config.xml | sed 's/<[^>]*>//g')
curl -H "X-API-Key: $KEY" http://127.0.0.1:8384/rest/config/folders        # список папок
curl -H "X-API-Key: $KEY" "http://127.0.0.1:8384/rest/db/status?folder=<id>"

# Chezmoi — точная проверка конкретного пути (обязательно перед mv/rm)
chezmoi managed | grep -Fx 'Pictures/файл'     # managed ли ИМЕННО этот файл
chezmoi managed | grep -Fx 'test_x.sh'
chezmoi diff                                   # что apply собирается изменить (до apply)
chezmoi edit <target> --apply                  # правка managed-файла

# XDG: не схлопнуты ли каталоги в $HOME/?
grep -n '\$HOME/"' ~/.config/user-dirs.dirs
xdg-user-dir MUSIC                             # куда реально указывает

# Trash: определение пути + снятие read-only (Go module cache 0555)
ls -d ~/.trash ~/.local/share/Trash 2>/dev/null
chmod -R u+w ~/.trash/<dir> && rm -rf ~/.trash/<dir>

# Перед удалением каталога — не mountpoint ли?
mountpoint ~/reports || findmnt -T ~/reports

# Большие деревья — только ripgrep
rg -l 'pattern' ~/projects ~/dotfiles ~/.config

# Dsync
dsync status; dsync pull
```
