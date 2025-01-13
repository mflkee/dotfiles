#!/bin/bash

# Проверяем, запущена ли запись
if pgrep -f "ffmpeg.*x11grab.*-f pulse" > /dev/null; then
  echo "%{F#ff5454}%{T8}󰑋"
else
  echo "%{F#949494}%{T8}󰑊"
fi
