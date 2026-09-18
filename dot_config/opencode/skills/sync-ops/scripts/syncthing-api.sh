#!/usr/bin/env bash
# Syncthing REST helper (GET) для случаев, когда MCP sync-ops недоступен.
# Ключ берётся из SYNCTHING_API_KEY или из config.xml. GUI слушает 127.0.0.1.
#
# Usage:
#   syncthing-api.sh /rest/system/status
#   SYNCTHING_URL=http://127.0.0.1:8384 syncthing-api.sh /rest/system/connections
#
# Только чтение. Мутации — через MCP sync-ops (st-*), НЕ этим скриптом.
set -euo pipefail

KEY="${SYNCTHING_API_KEY:-}"
if [ -z "$KEY" ]; then
  config="${SYNCTHING_CONFIG:-$HOME/.local/state/syncthing/config.xml}"
  KEY="$(grep -oP '(?<=<apikey>)[^<]+' "$config" 2>/dev/null || true)"
fi
if [ -z "$KEY" ]; then
  echo "Ошибка: API-ключ не найден (SYNCTHING_API_KEY или $config)" >&2
  exit 1
fi

URL="${SYNCTHING_URL:-http://127.0.0.1:8384}"
curl -s -m 5 -H "X-API-Key: $KEY" "${URL}${1:?Usage: syncthing-api.sh /rest/...}"