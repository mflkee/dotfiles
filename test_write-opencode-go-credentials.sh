#!/bin/bash
# Scenarios for sync_secrets in dot_local/bin/opencode-go-auth: how the token
# gets into ~/.config/zsh/secrets.zsh. Runs against a throwaway $HOME, so it
# never touches the real secrets file. Not deployed by chezmoi (see
# .chezmoiignore) - it lives in the repo as the regression test for that script.
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
auth="$here/dot_local/bin/executable_opencode-go-auth"
[ -f "$auth" ] || { echo "cannot find $auth - run this from ~/dotfiles"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
export SECRETS="$HOME/.config/zsh/secrets.zsh"
export CREDS="$HOME/.config/opencode-go/credentials.json"
mkdir -p "$HOME/.config/zsh" "$HOME/.config/opencode-go"
export SYNC_FN="$work/sync_fn.sh"

# Only the pieces under test: the marker globals and the function itself.
sed -n '/^SECRETS=/,/^SECRETS_END=/p;/^sync_secrets()/,/^}/p' "$auth" > "$SYNC_FN"
cat >> "$SYNC_FN" <<'EOF'
log() { printf '%s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
creds_field() { jq -r --arg k "$1" '.[$k] // empty' "$CREDS"; }
EOF

run() { OPENCODE_GO_NO_PUSH=1 bash -c 'source "$SYNC_FN"; sync_secrets' 2>&1; }
setcreds() { jq -n --arg o "$1" --arg t "$2" --argjson e "$3" \
  '{org_id:$o, access_token:$t, expires_at:$e}' > "$CREDS"; }
block() {
  awk '/^# >>> opencode-go-auth >>>$/{f=1;next} /^# <<< opencode-go-auth <<<$/{f=0;next} f' "$SECRETS"
}
checks=0; fails=0
check() { checks=$((checks+1)); if [ "$2" = "$3" ]; then echo "  ok: $1"; else echo "  FAIL: $1"; echo "    want: [$2]"; echo "    got:  [$3]"; fails=$((fails+1)); fi; }

echo "### A: fresh file, no trailing newline, no block yet"
printf '# header\nexport A="1"' > "$SECRETS"
setcreds wrk_X st_y 123
run > /dev/null
check "block appended" \
  'export OPENCODE_GO_ORG="wrk_X"
export OPENCODE_GO_TOKEN="st_y"
export OPENCODE_GO_EXPIRES_AT="123"' "$(block)"
check "markers present" "1" "$(grep -c '^# >>> opencode-go-auth >>>$' "$SECRETS")"
check "rest of file intact" '# header
export A="1"' "$(sed -n '1,2p' "$SECRETS")"
check "no trailing newline" "" "$(tail -c 1 "$SECRETS" | sed -n '/^$/p')"
check "file ends with newline" "yes" "$([ -z "$(tail -c 1 "$SECRETS")" ] && echo yes || echo no)"

echo "### B: idempotent"
cp "$SECRETS" "$SECRETS.snap"
run > /dev/null
check "second run is a no-op" "same" "$(cmp -s "$SECRETS.snap" "$SECRETS" && echo same || echo differs)"

echo "### C: replaces an existing block, keeps neighbours"
python3 - "$SECRETS" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text()
b, e = "# >>> opencode-go-auth >>>", "# <<< opencode-go-auth <<<"
s = s.replace(f'{b}\nexport OPENCODE_GO_ORG="wrk_X"\nexport OPENCODE_GO_TOKEN="st_y"\nexport OPENCODE_GO_EXPIRES_AT="123"\n{e}',
              f'{b}\nexport OPENCODE_GO_ORG="wrk_OLD"\nGARBAGE\nexport OPENCODE_GO_TOKEN="st_OLD"\n{e}')
p.write_text(s)
PY
setcreds wrk_NEW st_new 999
run > /dev/null
check "new values, garbage gone" \
  'export OPENCODE_GO_ORG="wrk_NEW"
export OPENCODE_GO_TOKEN="st_new"
export OPENCODE_GO_EXPIRES_AT="999"' "$(block)"
check "no GARBAGE left" "0" "$(grep -c GARBAGE "$SECRETS")"

echo "### D: logout empties the block but keeps the markers"
: > "$CREDS"
run > /dev/null
check "block emptied" '# no credentials - run: opencode-go-auth login' "$(block)"
check "markers kept" "2" "$(grep -c 'opencode-go-auth \(>>>\|<<<\)' "$SECRETS")"
check "other secrets untouched" "export A=\"1\"" "$(grep '^export A=' "$SECRETS")"

echo "### E: refuses a token with shell metacharacters"
rm -rf /tmp/pwned
setcreds 'wrk_X' 'st_$(rm -rf /tmp/pwned)' 1
out="$(run)"
check "nothing executed" "0" "$([ -d /tmp/pwned ] && echo 1 || echo 0)"
case "$out" in
  *"unexpected characters"*) echo "  ok: error message" ;;
  *) echo "  FAIL: no error message, got: $out"; fails=$((fails+1)) ;;
esac
check "secrets.zsh untouched" '# no credentials - run: opencode-go-auth login' "$(block)"

echo "### F: only one block, even if run repeatedly after a change"
setcreds wrk_1 st_1 1; run >/dev/null
setcreds wrk_2 st_2 2; run >/dev/null
setcreds wrk_3 st_3 3; run >/dev/null
check "one begin marker" "1" "$(grep -c 'opencode-go-auth >>>' "$SECRETS")"
check "one end marker" "1" "$(grep -c 'opencode-go-auth <<<' "$SECRETS")"
check "last value wins" "wrk_3" "$(grep '^export OPENCODE_GO_ORG=' "$SECRETS" | tr -d '"' | cut -d= -f2)"

echo
echo "$((checks-fails))/$checks checks passed"
[ "$fails" -eq 0 ] || exit 1
