#!/usr/bin/env bash
# Включить netbird-guard.timer на машинах, где есть NetBird (идемпотентно).
# Юнит и скрипт приезжают из chezmoi; здесь только enable --now, без sudo.
set -uo pipefail

if ! command -v netbird >/dev/null 2>&1; then
    exit 0
fi
if [ ! -f "$HOME/.config/systemd/user/netbird-guard.timer" ]; then
    exit 0
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now netbird-guard.timer >/dev/null 2>&1 || true
