#!/bin/bash
# Enable the OpenCode Go user timers on this machine (idempotent).
# Managed by chezmoi; runs whenever this file changes.
#
#   opencode-rotate.timer       — 1st & 16th, sets the half-month account
#                                 (idempotent `rotate`, safe to run on every machine)
#   opencode-go-tokencheck.timer — daily, warns when a token nears expiry
#
# No-op on machines without a systemd user manager (e.g. headless containers).
[ -d "${HOME}/.config/systemd/user" ] || exit 0
command -v systemctl >/dev/null 2>&1 || exit 0
systemctl --user enable --now opencode-rotate.timer opencode-go-tokencheck.timer \
  >/dev/null 2>&1 || true
exit 0
