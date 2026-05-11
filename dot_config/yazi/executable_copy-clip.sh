#!/bin/sh
WAYLAND_DISPLAY=wayland-1 wl-copy --type "$(file --mime-type -b "$1")" < "$1"
