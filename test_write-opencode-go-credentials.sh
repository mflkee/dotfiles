#!/bin/bash
# Scenarios for sync_secrets in dot_local/bin/opencode-go-auth (v2: аккаунты A/B).
# Runs against a throwaway $HOME, so it never touches the real secrets file.
# Not deployed by chezmoi (see .chezmoiignore) - it lives in the repo as the
# regression test for that script.
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
auth="$here/dot_local/bin/executable_opencode-go-auth"
[ -f "$auth" ] || { echo "cannot find $auth - run this from ~/dotfiles"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
export SECRETS="$HOME/.config/zsh/secrets.zsh"
export OPENCODE_GO_BASE="$HOME/.config/opencode-go"
export OPENCODE_GO_CREDS="$HOME/.config/opencode-go/credentials.json"
export OPENCODE_GO_ACCOUNTS="$HOME/.config/opencode-go/accounts"
export OPENCODE_GO_CURRENT_FILE="$HOME/.config/opencode-go/current"
export OPENCODE_GO_REQ="$HOME/.config/opencode-go/switch-request"
mkdir -p "$HOME/.config/zsh" "$HOME/.config/opencode-go/accounts"
export SYNC_FN="$work/sync_fn.sh"

BASE="$OPENCODE_GO_BASE"
ACCOUNTS_DIR="$OPENCODE_GO_ACCOUNTS"
CURRENT_FILE="$OPENCODE_GO_CURRENT_FILE"
CREDS="$OPENCODE_GO_CREDS"

# Only the pieces under test: the marker globals and sync_secrets + sync_empty_block.
sed -n '/^SECRETS=/,/^SECRETS_END=/p;/^sync_secrets()/,/^}/p;/^sync_empty_block()/,/^}/p' "$auth" > "$SYNC_FN"
cat >> "$SYNC_FN" <<'EOF'
log() { printf '%s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
BASE="${OPENCODE_GO_BASE:-$HOME/.config/opencode-go}"
ACCOUNTS_DIR="${OPENCODE_GO_ACCOUNTS:-$BASE/accounts}"
CURRENT_FILE="${OPENCODE_GO_CURRENT_FILE:-$BASE/current}"
CREDS="${OPENCODE_GO_CREDS:-$BASE/credentials.json}"
account_list() {
  for f in "$ACCOUNTS_DIR"/*.json; do
    [ -f "$f" ] || continue
    printf '%s\n' "$(basename "$f" .json)"
  done | sort
}
account_field() {
  local name="$1" field="$2"
  jq -r --arg k "$field" '.[$k] // empty' "$ACCOUNTS_DIR/$name.json"
}
active_name() {
  [ -f "$CURRENT_FILE" ] || return 1
  local n; n="$(cat "$CURRENT_FILE" 2>/dev/null || true)"
  printf '%s' "$n"
}
set_current() {
  local name="$1"
  printf '%s\n' "$name" > "$CURRENT_FILE"
}
EOF

acct() { # acct <name> <org> <token> <expires>
  jq -n --arg o "$2" --arg t "$3" --argjson e "$4" \
    '{org_id:$o, access_token:$t, expires_at:$e}' > "$ACCOUNTS_DIR/$1.json"
}
block() {
  awk '/^# >>> opencode-go-auth >>>$/{f=1;next} /^# <<< opencode-go-auth <<<$/{f=0;next} f' "$SECRETS"
}
env_of() { # env_of <NAME> печатает export-строку из секретов
  grep "^export $1=" "$SECRETS" | head -1
}
run() { OPENCODE_GO_NO_PUSH=1 bash -c 'source "$SYNC_FN"; sync_secrets' 2>&1; }

checks=0; fails=0
check() { checks=$((checks+1)); if [ "$2" = "$3" ]; then echo "  ok: $1"; else echo "  FAIL: $1"; echo "    want: [$2]"; echo "    got:  [$3]"; fails=$((fails+1)); fi; }

echo "### A: один аккаунт a -> CURRENT + A-переменные + легаси"
printf 'a\n' > "$CURRENT_FILE"
acct a wrk_A st_a 111
printf '# header\nexport A="1"' > "$SECRETS"
run > /dev/null
check "CURRENT в блоке" 'export OPENCODE_GO_CURRENT="a"' "$(env_of OPENCODE_GO_CURRENT)"
check "ORG_A в блоке" 'export OPENCODE_GO_ORG_A="wrk_A"' "$(env_of OPENCODE_GO_ORG_A)"
check "TOKEN_A в блоке" 'export OPENCODE_GO_TOKEN_A="st_a"' "$(env_of OPENCODE_GO_TOKEN_A)"
check "легаси ORG = активный" 'export OPENCODE_GO_ORG="wrk_A"' "$(env_of OPENCODE_GO_ORG)"
check "другие секреты целы" 'export A="1"' "$(grep '^export A=' "$SECRETS")"

echo "### B: два аккаунта a/b, активный b"
printf 'b\n' > "$CURRENT_FILE"
acct b wrk_B st_b 222
run > /dev/null
check "ORG_A сохранён" 'export OPENCODE_GO_ORG_A="wrk_A"' "$(env_of OPENCODE_GO_ORG_A)"
check "ORG_B в блоке" 'export OPENCODE_GO_ORG_B="wrk_B"' "$(env_of OPENCODE_GO_ORG_B)"
check "легаси = b (активный)" 'export OPENCODE_GO_ORG="wrk_B"' "$(env_of OPENCODE_GO_ORG)"
check "только один блок" "1" "$(grep -c 'opencode-go-auth >>>' "$SECRETS")"

echo "### C: идемпотентность (второй прогон не меняет файл)"
cp "$SECRETS" "$SECRETS.snap"
run > /dev/null
check "второй прогон — no-op" "same" "$(cmp -s "$SECRETS.snap" "$SECRETS" && echo same || echo differs)"

echo "### D: без токенов — пустой блок, остальное цело"
rm -f "$ACCOUNTS_DIR"/*.json
run > /dev/null
check "блок пуст" "# no credentials - run: opencode-go-auth login" "$(block)"
check "маркеры на месте" "2" "$(grep -c 'opencode-go-auth \(>>>\|<<<\)' "$SECRETS")"

echo "### E: отказ от метасимволов"
acct a 'wrk_$(rm -rf /tmp/pwned)' st_a 1
rm -rf /tmp/pwned
out="$(run)"
check "ничего не выполнилось" "0" "$([ -d /tmp/pwned ] && echo 1 || echo 0)"
case "$out" in
  *"unexpected"*) echo "  ok: error message" ;;
  *) echo "  FAIL: no error message, got: $out"; fails=$((fails+1)) ;;
esac

echo
echo "$((checks-fails))/$checks checks passed"
[ "$fails" -eq 0 ] || exit 1