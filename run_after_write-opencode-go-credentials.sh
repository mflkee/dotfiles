#!/bin/bash
# vim: ft=bash
# Materialise the OpenCode Go widget credentials from secrets.zsh.
# Managed by chezmoi
#
# v2: аккаунты A/B. Токены лежат в зашифрованном ~/.config/zsh/secrets.zsh
# (единственное место в репо). На каждом `chezmoi apply` этот скрипт пишет:
#   accounts/<name>.json        для каждого аккаунта (ORG/TOKEN/EXPIRES_<NAME>)
#   credentials.json            копия АКТИВНОГО аккаунта (виджет читает его)
#   current                     имя активного аккаунта (создаётся, если нет)
# Значения копируются дословно, никогда не парсятся как shell-код; файлы
# переписываются только при изменении содержимого.

set -uo pipefail

SECRETS="${HOME}/.config/zsh/secrets.zsh"
BASE="${HOME}/.config/opencode-go"
DIR="${BASE}/accounts"
CREDS="${BASE}/credentials.json"
CURRENT_FILE="${BASE}/current"

[ -f "$SECRETS" ] || exit 0

read_secret() {
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

write_json() {
  local target="$1" org="$2" token="$3" expires="$4"
  [ -n "$org" ] && [ -n "$token" ] || return 1
  case "$expires" in
    ''|*[!0-9]*) expires=0 ;;
  esac
  local tmp; tmp="$(mktemp "${target}.XXXXXX" 2>/dev/null)"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg org "$org" --arg token "$token" --argjson expires "$expires" \
      '{org_id: $org, access_token: $token, expires_at: $expires}' >"$tmp" || { rm -f "$tmp"; return 1; }
  else
    printf '{"org_id":"%s","access_token":"%s","expires_at":%s}\n' \
      "$org" "$token" "$expires" >"$tmp"
  fi
  chmod 600 "$tmp"
  if [ ! -f "$target" ] || ! cmp -s "$tmp" "$target"; then
    mv -f "$tmp" "$target"
    chmod 600 "$target"
  else
    rm -f "$tmp"
  fi
  return 0
}

mkdir -p "$DIR" && chmod 700 "$BASE" 2>/dev/null || exit 0
umask 077

# Активный аккаунт (в v2 — OPENCODE_GO_CURRENT; легаси — просто первый).
active="$(read_secret OPENCODE_GO_CURRENT)"
[ -n "$active" ] || active=""

names=""
org="$(read_secret OPENCODE_GO_ORG_A)"; token="$(read_secret OPENCODE_GO_TOKEN_A)"
expires="$(read_secret OPENCODE_GO_EXPIRES_A)"
if [ -n "$org" ] && [ -n "$token" ]; then
  write_json "${DIR}/a.json" "$org" "$token" "$expires" && names="$names a"
fi
org="$(read_secret OPENCODE_GO_ORG_B)"; token="$(read_secret OPENCODE_GO_TOKEN_B)"
expires="$(read_secret OPENCODE_GO_EXPIRES_B)"
if [ -n "$org" ] && [ -n "$token" ]; then
  write_json "${DIR}/b.json" "$org" "$token" "$expires" && names="$names b"
fi

# Легаси: если B нет, но есть старые OPENCODE_GO_ORG/TOKEN — это аккаунт a.
if [ -z "$names" ]; then
  org="$(read_secret OPENCODE_GO_ORG)"; token="$(read_secret OPENCODE_GO_TOKEN)"
  expires="$(read_secret OPENCODE_GO_EXPIRES_AT)"
  if [ -n "$org" ] && [ -n "$token" ]; then
    write_json "${DIR}/a.json" "$org" "$token" "$expires" && names=" a"
    [ -n "$active" ] || active="a"
  fi
fi

[ -n "$names" ] || exit 0
[ -n "$active" ] || active="$(printf '%s\n' $names | tr -d ' ' | head -c 1)"

# credentials.json = копия активного (виджет не умеет в аккаунты).
act_file="${DIR}/${active}.json"
[ -f "$act_file" ] || act_file="$(ls "$DIR"/*.json 2>/dev/null | head -1)"
[ -n "$act_file" ] && [ -f "$act_file" ] || exit 0
org="$(jq -r '.org_id // empty' "$act_file" 2>/dev/null)"
token="$(jq -r '.access_token // empty' "$act_file" 2>/dev/null)"
expires="$(jq -r '.expires_at // 0' "$act_file" 2>/dev/null)"
write_json "$CREDS" "$org" "$token" "$expires"

# current: держим в соответствии с secrets (OPENCODE_GO_CURRENT — источник истины
# для флота). Пишем только при изменении содержимого.
if [ "$(cat "$CURRENT_FILE" 2>/dev/null || true)" != "$active" ]; then
  tmp="$(mktemp "${CURRENT_FILE}.XXXXXX" 2>/dev/null)" || tmp="${CURRENT_FILE}.tmp"
  if printf '%s\n' "$active" >"$tmp" 2>/dev/null; then
    chmod 600 "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$CURRENT_FILE" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi

# Best-effort: привести opencode CLI ЭТОЙ машины к активному аккаунту, но только
# когда аккаунт менялся с прошлого apply (маркер .cli-applied) и есть чем
# переключать. OPENCODE_GO_NO_CLI_SWITCH=1 отключает.
if [ "${OPENCODE_GO_NO_CLI_SWITCH:-0}" != "1" ] \
   && command -v opencode >/dev/null 2>&1 \
   && [ -f "${DIR}/${active}.cli" ] \
   && [ -x "${HOME}/.local/bin/opencode-go-auth" ]; then
  marker="${BASE}/.cli-applied"
  if [ "$(cat "$marker" 2>/dev/null || true)" != "$active" ]; then
    if "${HOME}/.local/bin/opencode-go-auth" apply >/dev/null 2>&1; then
      printf '%s\n' "$active" >"$marker" 2>/dev/null || true
    fi
  fi
fi

echo "[chezmoi] wrote accounts{${names// /,}} + credentials.json (active=$active)"