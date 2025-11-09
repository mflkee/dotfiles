#!/bin/bash
set -euo pipefail

STATE_FILE=${SPLIT_TUNNEL_STATE:-/run/vpn-manager/chatgpt-split.routes}
DOMAINS_RAW=${SPLIT_TUNNEL_DOMAINS:-}

log() {
  logger -t "chatgpt-split" "$*"
}

cleanup_routes() {
  if [[ -f "$STATE_FILE" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      if ip -4 route show "$entry" &>/dev/null; then
        ip -4 route del "$entry" 2>/dev/null || true
      fi
    done <"$STATE_FILE"
    rm -f "$STATE_FILE"
  fi
}

add_route() {
  local cidr=$1
  local gateway=${2:-}
  local dev_name=${3:-}
  if [[ -n "$gateway" ]]; then
    ip -4 route replace "$cidr" via "$gateway" dev "$dev_name" || true
  elif [[ -n "$dev_name" ]]; then
    ip -4 route replace "$cidr" dev "$dev_name" || true
  else
    ip -4 route replace "$cidr" || true
  fi
}

drop_default_split_routes() {
  if [[ -z "${dev:-}" ]]; then
    log "split-tunnel: missing dev when dropping default routes"
    return
  fi
  log "split-tunnel: dropping default split routes on ${dev}"
  ip -4 route del 0.0.0.0/1 dev "${dev}" 2>/dev/null || true
  ip -4 route del 128.0.0.0/1 dev "${dev}" 2>/dev/null || true
}

case "${script_type:-}" in
  route-up)
    mkdir -p "$(dirname "$STATE_FILE")"
    : >"$STATE_FILE"
    drop_default_split_routes
    gateway="${route_vpn_gateway:-${ifconfig_remote:-}}"
    if [[ -z "$dev" ]]; then
      log "split-tunnel: missing dev during route-up"
      exit 1
    fi
    if [[ -z "$gateway" ]]; then
      log "split-tunnel: missing VPN gateway, using interface routes on ${dev}"
    fi
    IFS=' ' read -r -a domains <<<"$DOMAINS_RAW"
    for domain in "${domains[@]}"; do
      [[ -z "$domain" ]] && continue
      mapfile -t resolved < <(getent ahostsv4 "$domain" | awk '{print $1}' | sort -u)
      if [[ ${#resolved[@]} -eq 0 ]]; then
        log "split-tunnel: no IPv4 records for ${domain}"
        continue
      fi
      for ipaddr in "${resolved[@]}"; do
        cidr="${ipaddr}/32"
        add_route "$cidr" "$gateway" "$dev"
        echo "$cidr" >>"$STATE_FILE"
      done
    done
    ;;
  route-pre-down|down-pre)
    cleanup_routes
    ;;
  down)
    cleanup_routes
    ;;
  *)
    exit 0
    ;;
esac
