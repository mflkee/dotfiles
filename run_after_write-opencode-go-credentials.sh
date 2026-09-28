#!/bin/bash
# vim: ft=bash
# Materialise the OpenCode Go widget credentials from secrets.zsh.
# Managed by chezmoi
#
# The token lives in exactly one place in the repo: the encrypted
# ~/.config/zsh/secrets.zsh. Noctalia does not read shell env, so on every
# `chezmoi apply` (including the one dsync runs after a pull) this writes the
# same three values out as the 0600 JSON the widget and `opencode-go-auth`
# expect. Run on every apply on purpose: the trigger for a new token is a new
# secrets.zsh, and chezmoi's run_onchange would only key off this script.
#
# Values are copied verbatim, never parsed as shell code, and the file is only
# rewritten when the content actually changes so the widget's mtime stays put.

set -uo pipefail

SECRETS="${HOME}/.config/zsh/secrets.zsh"
DIR="${HOME}/.config/opencode-go"
CREDS="${DIR}/credentials.json"

[ -f "$SECRETS" ] || exit 0

read_secret() {
  # Prints the value of the last matching `export NAME='...'` line, or nothing.
  # Handles single quotes, double quotes and bare values, ignores commented-out
  # lines. Values are base64/URL-safe by construction, so no quote can appear
  # inside them; anything unexpected is skipped rather than guessed at.
  local name="$1" value
  value="$(sed -n "s/^[[:space:]]*export[[:space:]]\+${name}=//p" "$SECRETS" | tail -n 1)" || exit 0
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  case "$value" in
    *[\'\"\\[:space:]]*) return 0 ;;
  esac
  [ -n "$value" ] && printf '%s' "$value"
}

org="$(read_secret OPENCODE_GO_ORG)"
token="$(read_secret OPENCODE_GO_TOKEN)"
expires="$(read_secret OPENCODE_GO_EXPIRES_AT)"

# No token (fresh machine before the first login, or after logout): leave
# whatever is there alone rather than replacing it with an empty file.
[ -n "$org" ] && [ -n "$token" ] || exit 0
case "$expires" in
  ''|*[!0-9]*) expires=0 ;;
esac

mkdir -p "$DIR" && chmod 700 "$DIR" || exit 0

umask 077
tmp="$(mktemp "${CREDS}.XXXXXX" 2>/dev/null)" || exit 0
trap 'rm -f "$tmp"' EXIT
if command -v jq >/dev/null 2>&1; then
  jq -n --arg org "$org" --arg token "$token" --argjson expires "$expires" \
    '{org_id: $org, access_token: $token, expires_at: $expires}' >"$tmp" || exit 0
else
  printf '{"org_id":"%s","access_token":"%s","expires_at":%s}\n' \
    "$org" "$token" "$expires" >"$tmp"
fi

mkdir -p "$DIR" && chmod 700 "$DIR"
if [ -f "$CREDS" ] && cmp -s "$tmp" "$CREDS"; then
  exit 0
fi
mv -f "$tmp" "$CREDS"
chmod 600 "$CREDS"
trap - EXIT
valid="$(date -d "@$expires" '+%Y-%m-%d' 2>/dev/null || echo '?')"
echo "[chezmoi] wrote $CREDS from secrets.zsh (token valid until $valid)"
