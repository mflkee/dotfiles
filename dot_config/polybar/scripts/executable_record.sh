#!/bin/bash

# Проверяем, запущена ли запись
if pgrep -f "ffmpeg.*x11grab.*-f pulse" > /dev/null; then
  echo "%{F#FF5D5D}%{T8}󰑋"
else
  echo "%{F#949494}%{T8}󰑊"
fi
