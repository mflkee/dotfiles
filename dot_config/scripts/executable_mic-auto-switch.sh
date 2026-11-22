#!/usr/bin/env bash
# Автовыбор системного микрофона (по умолчанию) между Bluetooth-наушниками и
# штатным микрофоном.
#
# Зачем: hyprwhspr (диктовка), браузеры и звонки пишут с СИСТЕМНОГО источника
# по умолчанию. Когда подключены OnePlus Buds Pro 3 (или любые BT-наушники с
# микрофоном), логично говорить в их микрофон, а после отключения — вернуть
# прежний (внутренний массив / USB-микрофон).
#
# Логика:
#   * есть bluez_card.* и источник bluez_input.* — делаем его дефолтным,
#     предварительно запомнив текущий (в файл состояния);
#   * карта/источник исчезли — возвращаем запомненный источник, если он ещё
#     существует; иначе просим WirePlumber выбрать лучший по приоритету
#     (wpctl clear-default 1 = Audio/Source).
#
# Слушает pactl subscribe (source/card/server), поэтому срабатывает на
# подключение/отключение наушников и на смену профиля HFP <-> A2DP.
#
# Запускается как user-сервис mic-auto-switch.service.
#
# Проверка:
#   systemctl --user status mic-auto-switch
#   journalctl --user -u mic-auto-switch -f
#   pactl get-default-source
#   wpctl status | sed -n '/Sources:/,/Filters:/p'

set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mic-auto-switch"
SAVED="$STATE_DIR/previous-source"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 1

log() { logger -t mic-auto-switch -- "$*" 2>/dev/null || true; }

pulse_up() { pactl info >/dev/null 2>&1; }

bt_card_present() {
  pactl list short cards 2>/dev/null | grep -q 'bluez_card\.'
}

bt_source() {
  pactl list short sources 2>/dev/null |
    awk '$2 ~ /^bluez_input\./ {print $2; exit}'
}

all_sources() {
  pactl list short sources 2>/dev/null | awk '{print $2}'
}

apply() {
  local want cur

  if bt_card_present; then
    want=$(bt_source)
    # Карта есть, а источника ещё нет (профиль A2DP, узел не создан) — ждём
    # следующего события, иначе сломаем текущий выбор.
    [ -z "$want" ] && return 0

    cur=$(pactl get-default-source 2>/dev/null || true)
    case "$cur" in
      bluez_input.*) ;;                    # уже микрофон наушников
      "") ;;                               # дефолта нет — запоминать нечего
      *) printf '%s\n' "$cur" > "$SAVED" ;; # запомнить прежний выбор
    esac
  else
    # Наушники отключены. Пауза: при переключении профиля HFP -> A2DP узлы
    # успевают пересоздаться, и без неё мы бы дёргали дефолт на каждый чих.
    sleep 2
    if bt_card_present && [ -n "$(bt_source)" ]; then
      return 0
    fi

    want=""
    if [ -s "$SAVED" ]; then
      want=$(cat "$SAVED")
      all_sources | grep -Fxq "$want" || want=""
    fi
    rm -f "$SAVED"

    if [ -z "$want" ]; then
      wpctl clear-default 1 >/dev/null 2>&1 || true
      log "bluetooth mic gone, no saved source: left to WirePlumber priority"
      return 0
    fi
  fi

  cur=$(pactl get-default-source 2>/dev/null || true)
  [ "$want" = "$cur" ] && return 0
  if pactl set-default-source "$want" 2>/dev/null; then
    log "default source -> $want (was ${cur:-unset})"
  fi
}

# Ждём звуковой сервер: сервис стартует вместе с графической сессией.
for _ in $(seq 1 60); do
  pulse_up && break
  sleep 0.5
done
pulse_up || { log "pulse server is not available"; exit 1; }

apply

pactl subscribe 2>/dev/null | while read -r event; do
  case "$event" in
    *"on source"*|*"on card"*|*"on server"*) apply ;;
  esac
done

# pactl subscribe завершился (сервер перезапустился) — пусть systemd поднимет заново
exit 1
