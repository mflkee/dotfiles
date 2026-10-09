#!/bin/sh
# tmux-session-jump.sh — переключить клиента на следующую/предыдущую сессию
# (просто «движение» по сессиям, окна не переносятся).
# Использование: tmux-session-jump.sh next <cur-session>
#                tmux-session-jump.sh prev <cur-session>
# Порядок сессий — как в `tmux ls` (тот же, что у tmux-movewin.sh),
# с замыканием с края на край.
dir="$1"
cur="$2"
if [ -z "$cur" ]; then
    cur=$(tmux display-message -p '#{session_name}' 2>/dev/null)
fi
[ -n "$cur" ] || exit 1

names=$(tmux ls -F '#{session_name}')

tgt=""
if [ "$dir" = "next" ]; then
    tgt=$(printf '%s\n' "$names" | awk -v c="$cur" '{if (f) { print; exit } f=($0==c)}')
    [ -z "$tgt" ] && tgt=$(printf '%s\n' "$names" | head -1)
else
    tgt=$(printf '%s\n' "$names" | awk -v c="$cur" '{if ($0==c) { print p; exit } p=$0}')
    [ -z "$tgt" ] && tgt=$(printf '%s\n' "$names" | tail -1)
fi

[ -n "$tgt" ] || exit 1
[ "$tgt" = "$cur" ] && exit 0

tmux switch-client -t "$tgt"
