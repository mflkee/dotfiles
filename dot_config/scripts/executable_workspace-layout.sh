#!/usr/bin/env bash
set -euo pipefail

# Авто-сборка рабочего окружения при логине (spawn-at-startup в niri).
#   ws 1 — браузер, ws 2 — терминалы, ws 3 — Obsidian.
# Скрипт запускает приложение, ждёт появления его окна и переносит
# колонку на целевой воркспейс (надёжнее, чем гонки focus/spawn).

NIRI="niri msg"

count_windows() { "$NIRI" windows 2>/dev/null | grep -c "Window ID"; }

# spawn_on_workspace <app-id для логирования> <воркспейс> <cmd...>
spawn_on_workspace() {
  local appid="$1" ws="$2" before after
  shift 2

  before=$(count_windows)
  "$@" &
  disown 2>/dev/null || true

  # Ждём появления нового окна (до 15 сек)
  after=$before
  for _ in $(seq 1 30); do
    after=$(count_windows)
    [[ "$after" -gt "$before" ]] && break
    sleep 0.5
  done

  # Окно появилось — переносим его колонку на целевой воркспейс.
  # Если приложение уже было открыто (нового окна нет) — не трогаем фокус.
  if [[ "$after" -gt "$before" ]]; then
    sleep 0.3
    "$NIRI" action move-column-to-workspace "$ws" 2>/dev/null || true
  fi
}

spawn_on_workspace "zen-browser" 1 zen-browser
spawn_on_workspace "ghostty" 2 ghostty
spawn_on_workspace "ghostty" 2 ghostty
spawn_on_workspace "obsidian" 3 obsidian

# Фокус — на рабочий воркспейс
"$NIRI" action focus-workspace 1 2>/dev/null || true