#!/bin/sh
# tmux-session-kill.sh — удалить сессию, не выкинув клиент из tmux.
#
# Зачем: если убить сессию, к которой привязан клиент (ту, на которой сейчас
# сидишь), tmux уничтожает и клиент — терминал просто отваливается в шелл, а
# остальные сессии живы.
#
# «Предыдущая сессия» = та, на которой клиент сидел до текущей (tmux-овский
# last-session, тот же, что у `switch-client -l`); если он указывает на
# убиваемую сессию — берём самую свежую по attach среди остальных.
#
# Использование:
#   tmux-session-kill.sh <сессия> [<клиент>]      # по имени
#   tmux-session-kill.sh id:3     [<клиент>]      # по id ($3) — так зовёт меню,
#                                                 # чтобы не экранировать имена
# Обычно вызывается алиасом tmux (ssd / ыыв) и меню (tmux-session-menu.sh).

target="${1:-}"
client="${2:-}"

LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
LOG="$LOGDIR/session-kill.log"
log() {
    mkdir -p "$LOGDIR" 2>/dev/null
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null
}
die() {
    echo "session-kill: $*" >&2
    log "FAIL target=$target client=$client: $*"
    exit 1
}

# Имя клиента — это путь к tty (/dev/pts/N). Пришло мусором или пустым
# (напр. вызов из шелла) — берём первый живой клиент.
case "$client" in
    /dev/*) [ -e "$client" ] || client="" ;;
    *) client="" ;;
esac
[ -n "$client" ] || client=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -1)

[ -n "$target" ] || target=$(tmux display-message -p '#{session_name}' 2>/dev/null)

# id:3 -> $3, имя -> =имя (точное совпадение, без префиксного матчинга)
case "$target" in
    id:*)
        sid="\$${target#id:}"
        target_name=$(tmux display-message -p -t "$sid" '#{session_name}' 2>/dev/null)
        kt="$sid"
        ;;
    "")
        target_name=""
        kt=""
        ;;
    *)
        target_name="$target"
        kt="=$target"
        ;;
esac
[ -n "$target_name" ] || die "сессия '$target' не найдена"

# switch-client с -c только когда клиент известен (без -c tmux берёт текущий).
sc() {
    if [ -n "$client" ]; then
        tmux switch-client -c "$client" "$@"
    else
        tmux switch-client "$@"
    fi
}

# Сессия, к которой сейчас привязан клиент.
client_session() {
    [ -n "$client" ] || return 1
    tmux list-clients -F '#{client_name} #{client_session}' 2>/dev/null |
        awk -v c="$client" '$1 == c { print $2; exit }'
}

cursess=$(client_session)

if [ "$cursess" = "$target_name" ]; then
    # Сессия под клиентом: сначала уходим на предыдущую.
    sc -l 2>/dev/null
    now=$(client_session)
    if [ -z "$now" ] || [ "$now" = "$target_name" ]; then
        # last-session не помог (нет его или он указывает на ту же сессию):
        # берём самую недавно использованную сессию кроме убиваемой.
        # session_last_attached у никогда не подключённой сессии пустой,
        # поэтому подставляем 0; разделитель «|» — чтобы имена с пробелами
        # не разваливались на поля.
        prev=$(tmux list-sessions -F '#{?session_last_attached,#{session_last_attached},0}|#{session_name}' 2>/dev/null |
            sort -t'|' -k1,1 -rn |
            awk -F'|' -v t="$target_name" '$2 != t { print $2; exit }')
        [ -n "$prev" ] || die "это последняя сессия tmux — переключаться некуда"
        sc -t "$prev" 2>/dev/null || die "не удалось переключиться на $prev"
        now=$(client_session)
        [ "$now" != "$target_name" ] || die "клиент всё ещё на $target_name, убивать опасно"
        log "switch $target_name -> $prev (last-session не сработал)"
    fi
fi

err=$(tmux kill-session -t "$kt" 2>&1) || die "$err"

log "ok: killed $target_name (client ${client:-none}, was ${cursess:-unknown})"
