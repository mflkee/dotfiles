#!/usr/bin/env bash
# Тесты для noctalia-lock-watchdog (защита от «коричневого экрана»).
#
# Контекст (2026-10-02): старая версия watchdog считала зависанием ЛЮБОЙ лок
# старше $TIMEOUT и перезапускала оболочку каждые 30 с, пока сессия
# заблокирована. На Noctalia v5.2.1 локскрин рисуется нормально, но этот цикл
# рвал ext-session-lock, после чего niri не смог перезапустить сессию
# («Failed to open session», os error 38) — пользователь получал пустой
# («коричневый») экран и уходил в ребут.
#
# Тесты гоняют реальный скрипт на заглушках noctalia/loginctl/systemctl.
# Запуск:  bash ~/dotfiles/test_noctalia-lock-watchdog.sh [путь-к-скрипту]
set -uo pipefail

W="${1:-$HOME/.local/bin/noctalia-lock-watchdog}"
[ -x "$W" ] || W="$HOME/dotfiles/dot_local/bin/executable_noctalia-lock-watchdog"

T="$(mktemp -d "${TMPDIR:-/tmp}/wd-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"
STATE="$T/state"
SD="$STATE/noctalia-lock-watchdog"
mkdir -p "$BIN" "$SD"

pass=0
fail=0

check() { # описание, 1=ок, детали
    if [ "${2:-}" = "1" ]; then
        printf '  \033[32mok\033[0m   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf '  \033[31mFAIL\033[0m %s%s\n' "$1" "${3:+ — $3}"
        fail=$((fail + 1))
    fi
}

y_or_n() { if [ "$1" = 0 ]; then echo 1; else echo 0; fi; }
has() { case "$1" in *"$2"*) echo 1 ;; *) echo 0 ;; esac; }
hasnot() { case "$1" in *"$2"*) echo 0 ;; *) echo 1 ;; esac; }

# noctalia: true/false — жив и рисует локскрин, dead — мёртв (нет IPC, как в жизни)
stub_noctalia() {
    case "$1" in
        dead)
            cat > "$BIN/noctalia" <<'EOF'
#!/bin/sh
exit 1
EOF
            ;;
        true)
            cat > "$BIN/noctalia" <<'EOF'
#!/bin/sh
echo '{"locked": true}'
exit 0
EOF
            ;;
        *)
            cat > "$BIN/noctalia" <<'EOF'
#!/bin/sh
echo '{"locked": false}'
exit 0
EOF
            ;;
    esac
    chmod +x "$BIN/noctalia"
}

# loginctl: LockHint всегда yes; rc для unlock-session задаётся аргументом
stub_loginctl() {
    cat > "$BIN/loginctl" <<EOF
#!/bin/sh
case "\$1" in
  unlock-session) echo "loginctl \$*" >> "$T/called"; exit $1 ;;
  show-session) echo yes; exit 0 ;;
  list-sessions) exit 0 ;;
esac
exit 1
EOF
    chmod +x "$BIN/loginctl"
}

stub_systemctl() {
    cat > "$BIN/systemctl" <<EOF
#!/bin/sh
echo "systemctl \$*" >> "$T/called"
exit 0
EOF
    chmod +x "$BIN/systemctl"
}

# $1 = возраст state-файла в секундах; пусто — файла нет
run_watchdog() {
    local age="${1:-}"
    rm -f "$T/called"
    if [ -n "$age" ]; then
        printf '%s\n' "$(( $(date +%s) - age ))" > "$SD/locked-since"
    else
        rm -f "$SD/locked-since"
    fi
    XDG_SESSION_ID=c1 XDG_CACHE_HOME="$STATE" PATH="$BIN:$PATH" \
        LOCK_WATCHDOG_TIMEOUT=120 LOCK_WATCHDOG_MIN_INTERVAL=30 \
        sh "$W" > "$T/out" 2> "$T/err"
    RC=$?
}

calls() { [ -f "$T/called" ] || return 0; tr '\n' '|' < "$T/called"; }
errs() { [ -f "$T/err" ] || return 0; tr '\n' '|' < "$T/err"; }
pause_left() { # секунд до следующей попытки
    [ -f "$SD/locked-since" ] || { echo "нет-state-файла"; return; }
    echo $(( $(cat "$SD/locked-since") - $(date +%s) ))
}

echo "Скрипт: $W"

echo
echo "A. Сессия не заблокирована — ничего не делаем"
stub_noctalia false
stub_loginctl 0
stub_systemctl
run_watchdog ""
check "код возврата 0" "$(y_or_n "$RC")" "rc=$RC"
check "нет вызовов loginctl/systemctl" "$([ -z "$(calls)" ] && echo 1 || echo 0)" "$(calls)"

echo
echo "B. Нормальный лок (noctalia жива) — рестарта быть НЕ должно (регрессия)"
stub_noctalia true
stub_loginctl 0
stub_systemctl
run_watchdog ""
check "код возврата 0" "$(y_or_n "$RC")" "rc=$RC"
check "systemctl НЕ вызван" "$(hasnot "$(calls)" systemctl)" "$(calls)"
check "state-файл убран" "$([ ! -f "$SD/locked-since" ] && echo 1 || echo 0)"
check "в логе нет «не отрисовался»" "$(hasnot "$(errs)" отрисовался)" "$(errs)"

echo
echo "C. Лок, noctalia мёртва, состояние только появилось — начинаем ждать"
stub_noctalia dead
stub_loginctl 0
stub_systemctl
run_watchdog ""
check "код возврата 0" "$(y_or_n "$RC")" "rc=$RC"
check "ни loginctl, ни systemctl" "$([ -z "$(calls)" ] && echo 1 || echo 0)" "$(calls)"
check "state-файл создан" "$([ -f "$SD/locked-since" ] && echo 1 || echo 0)"
check "в лог ушла запись о старте ожидания" "$(has "$(errs)" 'жду до')" "$(errs)"

echo
echo "D. Лок, noctalia мёртва, прошло 30с из 120 — тихо ждём"
run_watchdog 30
check "код возврата 0" "$(y_or_n "$RC")" "rc=$RC"
check "ни loginctl, ни systemctl" "$([ -z "$(calls)" ] && echo 1 || echo 0)" "$(calls)"

echo
echo "E. Лок, noctalia мёртва, прошло 300с — снимаем лок через loginctl"
stub_loginctl 0
run_watchdog 300
check "код возврата 0" "$(y_or_n "$RC")" "rc=$RC"
check "loginctl unlock-session вызван" "$(has "$(calls)" 'unlock-session c1')" "$(calls)"
check "оболочку НЕ перезапускали" "$(hasnot "$(calls)" systemctl)" "$(calls)"
check "state-файл убран" "$([ ! -f "$SD/locked-since" ] && echo 1 || echo 0)"
check "в лог ушла запись про loginctl" "$(has "$(errs)" loginctl)" "$(errs)"

echo
echo "F. loginctl не помог — откат на перезапуск оболочки + пауза перед повтором"
stub_loginctl 1
run_watchdog 300
check "код возврата 0" "$(y_or_n "$RC")" "rc=$RC"
check "сначала попробован loginctl unlock-session" "$(has "$(calls)" 'unlock-session c1')" "$(calls)"
check "затем перезапуск noctalia-shell" "$(has "$(calls)" 'restart noctalia-shell.service')" "$(calls)"
check "пауза перед повтором (лево=$(pause_left)s)" \
    "$([ "$(pause_left | grep -cE '^(2[5-9]|3[0-5])$')" = 1 ] && echo 1 || echo 0)" "$(pause_left)"

echo
printf 'итого: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
