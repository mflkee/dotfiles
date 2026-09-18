#!/usr/bin/env bash
# recipe-save: scaffold.sh
# Создаёт каркас рецепт-скилла по шаблону recipe-save и логирует создание.
# usage: scaffold.sh --id <kebab-id> [--scope global|project] [--trigger auto|manual]
#        [--name "Name"] [--description "when to use"] [--project <root>]
set -euo pipefail

usage() {
  cat <<'EOF'
usage: scaffold.sh --id <kebab-id> [--scope global|project] [--trigger auto|manual]
       [--name "Name"] [--description "when to use"] [--project <root>]
EOF
  exit 1
}

ID="" SCOPE="project" TRIGGER="manual" NAME="" DESC="" PROJECT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --trigger) TRIGGER="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --description) DESC="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$ID" ]] || usage
case "$SCOPE" in global|project) ;; *) usage ;; esac
case "$TRIGGER" in auto|manual) ;; *) usage ;; esac

# Нормализация id: kebab-case ascii
ID="$(printf '%s' "$ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//')"
[[ -n "$ID" ]] || usage

PROJECT="${PROJECT:-$PWD}"

case "$SCOPE" in
  global)
    DEST="$HOME/.config/opencode/skills/$ID"
    CREATION_LOG="$HOME/.local/share/opencode/recipe-log.md"
    RUN_LOG="$HOME/.local/share/opencode/recipe-logs/$ID/run.log"
    ;;
  project)
    DEST="$PROJECT/.opencode/skills/$ID"
    CREATION_LOG="$PROJECT/.opencode/recipe-log.md"
    RUN_LOG="$PROJECT/.opencode/recipe-logs/$ID/run.log"
    ;;
esac

[[ -e "$DEST" ]] && { echo "error: $DEST already exists" >&2; exit 1; }

if [[ "$TRIGGER" == auto ]]; then
  printf -v META 'metadata:\n  opencode/autoinvoke: true'
else
  printf -v META 'slash: true\nmetadata:\n  opencode/autoinvoke: false'
fi

NAME="${NAME:-$ID}"
DESC="${DESC:-TODO: одна строка — когда применять этот рецепт}"

mkdir -p "$DEST/scripts" "$DEST/references"

cat > "$DEST/SKILL.md" <<MD
---
name: $NAME
description: $DESC
trigger: $TRIGGER
created: $(date +%F)
$META
---

# $NAME

## Задача
TODO: что решаем (1–3 строки)

## Этапы
1. TODO: только то, что СРАЗУ сработало, в рабочем порядке

## Команды и конфиги
TODO: точные команды / готовые куски / конфиги

## Вспомогательные файлы
- scripts/…
- references/…

## Логирование
Выполнение скриптов рецепта пишется в: $RUN_LOG

## Подводные камни
- TODO: что НЕ пробовать
MD

mkdir -p "$(dirname "$CREATION_LOG")" "$(dirname "$RUN_LOG")"
printf -- '- %s создан скилл `%s` (scope=%s, trigger=%s) → %s\n' \
  "$(date -Is)" "$ID" "$SCOPE" "$TRIGGER" "$DEST" >> "$CREATION_LOG"
printf -- '- %s scaffold из recipe-save (scope=%s)\n' "$(date -Is)" "$SCOPE" >> "$RUN_LOG"

echo "created: $DEST"
echo "creation log: $CREATION_LOG"
echo "run log: $RUN_LOG"