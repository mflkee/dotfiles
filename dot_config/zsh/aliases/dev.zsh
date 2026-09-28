# Development
alias g++='g++ -std=c++23'
alias rr='yazi'
alias fm='yazi'
alias files='yazi'
alias lg='lazygit'
alias vim='nvim'

alias hfga='hurl --resolve fgis.gost.ru:443:212.164.138.19 --connect-timeout 10 -m 25 --retry 0 --variables-file /home/mflkee/project/metrologenerator/tests/hurl/arshin.vars'
alias oc='opencode'

# rustrade dashboard: на сервере — локально (порт там уже слушается), на
# остальных машинах — поднять systemd-туннель rustrade-tunnel.service и открыть.
rd() {
  local url="http://127.0.0.1:8787"
  [[ "$(hostname)" == archlinux-server ]] && { xdg-open "$url" &>/dev/null &!; return; }
  systemctl --user is-active --quiet rustrade-tunnel.service 2>/dev/null ||
    systemctl --user start rustrade-tunnel.service 2>/dev/null
  sleep 0.3
  xdg-open "$url" &>/dev/null &!
}
