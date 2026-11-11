#!/bin/sh
# tmux-movewin.sh — переместить текущую вкладку в следующую/предыдущую сессию.
# Использование: tmux-movewin.sh next <cur-session> <src-window>
#                tmux-movewin.sh prev <cur-session> <src-window>
# Обычно вызывается алиасом tmux (mvn/mvp), который подставляет
# <cur-session> = "#{session_name}" и <src-window> = "#{window_id}" (@N).
# Поддерживается и старый вид <src-window> = "session:index" — но он ломкий:
# при renumber-windows номер окна успевает измениться между нажатием и запуском
# скрипта, и move-window падает с «can't find window: N» (returned 1).
dir="$1"
cur="$2"
src="$3"
[ -n "$src" ] || { echo "movewin: не передан src-window" >&2; exit 1; }

# Параллельные запуски (быстрый макрос может выстрелить дважды) сериализуем:
# второй вызов увидел бы уже перенесённое окно и портил бы только раскладку.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/tmux-movewin.$(id -u).lock"
if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK" 2>/dev/null && { flock -w 3 9 || exit 0; }
fi

LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
LOG="$LOGDIR/movewin.log"
log() {
    mkdir -p "$LOGDIR" 2>/dev/null
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null
}

die() {
    echo "movewin: $*" >&2
    log "FAIL dir=$dir cur=$cur src=$src: $*"
    exit 1
}

# Сессия исходного окна — по window_id (@N) или по "session:index".
if [ "${src#@}" != "$src" ]; then
    srcsess=$(tmux list-windows -a -F '#{window_id} #{session_name}' 2>/dev/null |
        awk -v w="$src" '$1 == w { print $2; exit }')
    [ -n "$srcsess" ] || die "окно $src уже не существует"
else
    srcsess=${src%%:*}
fi

names=$(tmux ls -F '#{session_name}' 2>/dev/null)
[ -n "$names" ] || die "не удалось получить список сессий tmux"

[ -n "$cur" ] || cur="$srcsess"

tgt=""
if [ "$dir" = "next" ]; then
    tgt=$(printf '%s\n' "$names" | awk -v c="$cur" '{if (f) { print; exit } f=($0==c)}')
    [ -z "$tgt" ] && tgt=$(printf '%s\n' "$names" | head -1)
else
    tgt=$(printf '%s\n' "$names" | awk -v c="$cur" '{if ($0==c) { print p; exit } p=$0}')
    [ -z "$tgt" ] && tgt=$(printf '%s\n' "$names" | tail -1)
fi

[ -n "$tgt" ] || die "не найдена целевая сессия (cur=$cur)"
# Окно уже в целевой сессии — ничего не делаем (повторный вызов, устаревший @id).
[ "$tgt" = "$srcsess" ] && exit 0

# Сначала переключаем клиента на целевую сессию, потом переносим окно:
# если переносится последнее окно текущей сессии, она уничтожается,
# но клиент уже не привязан к ней и не отвалится.
tmux switch-client -t "$tgt" 2>/dev/null

err=$(tmux move-window -s "$src" -t "$tgt" 2>&1) || die "$err"

# Остаёмся в перенесённом окне (move-window кладёт его в конец и не выбирает).
tmux select-window -t "$src" 2>/dev/null
log "ok $dir: $src ($srcsess) -> $tgt"
