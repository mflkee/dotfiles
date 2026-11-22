#!/bin/sh
# tmux-session-kill.sh — удалить сессию, не выкинув клиент из tmux.
#
# Зачем: если убить сессию, к которой привязан клиент (ту, на которой сейчас
# сидишь), tmux уничтожает и клиент — терминал просто отваливается в шелл, а
# остальные сессии живы. В дереве сессий (`C-a s`) это лечится только так:
# сначала пересадить клиента на предыдущую сессию, потом убить старую.
# Перебиндить клавиши внутри дерева нельзя — там клавиши зашиты в tmux
# (таблицы tree-mode не существует, `list-keys -T tree-mode` её не находит).
#
# «Предыдущая сессия» = та, на которой клиент сидел до текущей (tmux-овский
# last-session, тот же, что у `switch-client -l`); если он указывает на
# убиваемую сессию — берём самую свежую по attach среди остальных.
#
# Использование:
#   tmux-session-kill.sh <сессия> [<клиент>]
# Обычно вызывается алиасом tmux (ssd / ыыв), который подставляет
# <сессия> = "#{session_name}", <клиент> = "#{client_name}".

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

if [ -z "$target" ]; then
    target=$(tmux display-message -p '#{session_name}' 2>/dev/null)
fi
[ -n "$target" ] || die "не удалось определить сессию"

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

if [ "$cursess" = "$target" ]; then
    # Сессия под клиентом: сначала уходим на предыдущую.
    sc -l 2>/dev/null
    now=$(client_session)
    if [ -z "$now" ] || [ "$now" = "$target" ]; then
        # last-session не помог (нет его или он указывает на ту же сессию):
        # берём самую недавно использованную сессию кроме убиваемой.
        prev=$(tmux list-sessions -F '#{session_last_attached} #{session_name}' 2>/dev/null |
            sort -rn |
            awk -v t="$target" '$2 != t { print $2; exit }')
        [ -n "$prev" ] || die "это последняя сессия tmux — переключаться некуда"
        sc -t "$prev" 2>/dev/null || die "не удалось переключиться на $prev"
        now=$(client_session)
        [ "$now" != "$target" ] || die "клиент всё ещё на $target, убивать опасно"
        log "switch $target -> $prev (last-session не сработал)"
    fi
fi

err=$(tmux kill-session -t "=$target" 2>&1) || die "$err"

log "ok: killed $target (client ${client:-none}, was ${cursess:-unknown})"
