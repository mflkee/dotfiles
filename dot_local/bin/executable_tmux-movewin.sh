#!/bin/sh
# tmux-movewin.sh — переместить текущую вкладку в следующую/предыдущую сессию.
# Использование: tmux-movewin.sh next <cur-session> <src-window>
#                tmux-movewin.sh prev <cur-session> <src-window>
# Обычно вызывается алиасом tmux (mvn/mvp), который подставляет
# <cur-session> = "#{session_name}" и <src-window> = "#{session_name}:#{window_index}".
dir="$1"
cur="$2"
src="$3"
[ -n "$src" ] || exit 1

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

# Сначала переключаем клиента на целевую сессию, потом переносим окно:
# если переносится последнее окно текущей сессии, она уничтожается,
# но клиент уже не привязан к ней и не отвалится.
tmux switch-client -t "$tgt" 2>/dev/null
tmux move-window -s "$src" -t "$tgt"