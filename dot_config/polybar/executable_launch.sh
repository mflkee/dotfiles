#!/bin/bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

if type "xrandr" > /dev/null; then
  for monitor in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    if [ "$monitor" = "eDP-1" ]; then  # Замените на ваш основной монитор
      MONITOR=$monitor polybar -c ~/.config/polybar/config-primary example &
    else
      MONITOR=$monitor polybar -c ~/.config/polybar/config-secondary example &
    fi
  done
else
  polybar -c ~/.config/polybar/config-primary example &
fi
