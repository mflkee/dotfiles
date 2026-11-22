#!/usr/bin/env bash
# tmux-session-menu.sh — меню «Удалить сессию».
#
# Один экран со списком сессий: выбираешь цифрой/буквой или мышью — сессия
# удаляется. Если выбрал ту, в которой сидишь, клиент сначала переезжает на
# предыдущую сессию, поэтому из tmux не выкидывает (этим и отличается от `x`
# в дереве `C-a s` и от kill-pane по `C-a x`).
#
# Вызывается биндом C-a C-k (см. ~/.tmux.conf) или вручную.
#
# В display-menu передаём id сессии (id:N), а не имя: имена могут содержать
# пробелы и кавычки, а id — всегда $N и экранировать нечего.

set -uo pipefail

cur=$(tmux display-message -p '#{session_name}' 2>/dev/null)
client=$(tmux display-message -p '#{client_name}' 2>/dev/null)
kill="$HOME/.local/bin/tmux-session-kill.sh"
keys=(1 2 3 4 5 6 7 8 9 0 a b c d e f g h i j k l m n o p q r s t u v w x y z)

menu=()
i=0
while IFS=$'\t' read -r id name wins att; do
    [ -n "${name:-}" ] || continue
    [ "$i" -lt "${#keys[@]}" ] || break
    label="$name"
    [ "$name" = "$cur" ] && label="$name (текущая → уйдёшь на предыдущую)"
    [ "${att:-0}" -gt 0 ] 2>/dev/null && [ "$name" != "$cur" ] && label="$name (занята)"
    menu+=("$label" "${keys[$i]}" "run-shell '$kill id:${id#\$} $client'")
    i=$((i + 1))
done < <(tmux list-sessions -F '#{session_id}	#{session_name}	#{session_windows}	#{session_attached}' 2>/dev/null)

if [ "${#menu[@]}" -eq 0 ]; then
    tmux display-message 'нет сессий tmux'
    exit 0
fi

exec tmux display-menu -T '#[fg=#e6b450,bold] Удалить сессию' "${menu[@]}"
