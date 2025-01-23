#!/bin/bash

# Проверяем, запущена ли запись
if pgrep -f "ffmpeg.*x11grab.*-f pulse" > /dev/null; then
  echo "%{F#FF5555}%{T8}󰑋"
else
  echo "%{F#6272A4}%{T8}󰑊"
fi

#282A36
#44475A
#F8F8F2
#6272A4
#8BE9FD
#50FA7B
#FFB86C
#FF79C6
#BD93F9
#FF5555
#F1FA8C
