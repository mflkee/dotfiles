--!nonstrict
-- awgq VPN — виджет бара Noctalia для AmneziaWG.
--
-- Состояние туннеля читается дешёвыми командами (без `awgq status`, который
-- грузит Python ~1 c):
--   systemctl is-active <unit>   → active / inactive / failed
--   readlink -f <symlink>        → имя активного конфига
--   ip -4 -o addr show <iface>   → внутренний адрес туннеля
-- Тогл/включение/выключение идёт через `awgq`, чтобы отработал netbird-fix.
--
-- Клик — тогл, правый клик — сводка, IPC:
--   noctalia msg plugin mflkee/awgq:vpn focused toggle
--   noctalia msg plugin mflkee/awgq:vpn focused on|off|refresh

local COLOR_ON = "primary"
local COLOR_OFF = "on_surface_variant"
local COLOR_BUSY = "primary"

-- ── settings ─────────────────────────────────────────────────────────────────

local function setting(key, fallback)
  local value = noctalia.getConfig(key)
  if value == nil then
    return fallback
  end
  return value
end

local UNIT = tostring(setting("unit", "awg-quick@wg0.service"))
local IFACE = tostring(setting("interface", "wg0"))
local SYMLINK = tostring(setting("symlink", "/etc/amnezia/amneziawg/wg0.conf"))
local SHOW_CONFIG = setting("show_config", true) ~= false
local REFRESH_MS = math.max(1000, (tonumber(setting("refresh_seconds", 3)) or 3) * 1000)

local AWGQ = noctalia.expandPath("~/.local/bin/awgq")
if not noctalia.fileExists(AWGQ) then
  AWGQ = "awgq"
end

-- ── state ────────────────────────────────────────────────────────────────────

local state = "unknown" -- on | off | busy | unknown
local config = ""
local ip = ""
local detail = ""
local busy = false
local polling = false

-- ── helpers ──────────────────────────────────────────────────────────────────

local function shQuote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function truncate(s, n)
  if #s <= n then
    return s
  end
  return s:sub(1, n - 1) .. "…"
end

local function statusLabel()
  if state == "on" then
    return noctalia.tr("status.on")
  end
  if state == "busy" then
    return noctalia.tr("status.busy")
  end
  return noctalia.tr("status.off")
end

local function displayText()
  if state == "busy" then
    return noctalia.tr("status.busy")
  end
  if state == "on" then
    if SHOW_CONFIG and config ~= "" then
      return truncate(config, 16)
    end
    return noctalia.tr("status.on")
  end
  return noctalia.tr("status.off")
end

-- ── rendering ────────────────────────────────────────────────────────────────

local render

render = function()
  if state == "on" then
    barWidget.setGlyph("shield-lock")
    barWidget.setColor(COLOR_ON)
    barWidget.setGlyphColor(COLOR_ON)
  elseif state == "busy" then
    barWidget.setGlyph("loader")
    barWidget.setColor(COLOR_BUSY)
    barWidget.setGlyphColor(COLOR_BUSY)
  else
    barWidget.setGlyph("shield-off")
    barWidget.setColor(COLOR_OFF)
    barWidget.setGlyphColor(COLOR_OFF)
  end

  barWidget.setText(displayText())

  local rows = {
    { key = noctalia.tr("tooltip.status"), value = statusLabel() },
  }
  if config ~= "" then
    table.insert(rows, { key = noctalia.tr("tooltip.config"), value = config })
  end
  if ip ~= "" then
    table.insert(rows, { key = noctalia.tr("tooltip.ip"), value = ip })
  end
  if detail ~= "" then
    table.insert(rows, { key = noctalia.tr("tooltip.detail"), value = detail })
  end
  table.insert(rows, { key = noctalia.tr("tooltip.click"), value = noctalia.tr("tooltip.click_action") })
  barWidget.setTooltip(rows)
end

-- ── polling ──────────────────────────────────────────────────────────────────

local function pollCommand()
  local fmt = [==[
u=$(systemctl is-active %s 2>/dev/null)
c=$(basename "$(readlink -f %s 2>/dev/null)" .conf)
i=$(ip -4 -o addr show dev %s 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
printf '%%s\n%%s\n%%s\n' "$u" "$c" "$i"
]==]
  return string.format(fmt, shQuote(UNIT), shQuote(SYMLINK), shQuote(IFACE))
end

local poll

poll = function()
  polling = true
  local accepted = noctalia.runAsync(pollCommand(), function(result)
    polling = false
    local out = (result and result.stdout) or ""
    local lines = {}
    for line in out:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    local unitState = lines[1] or ""
    config = lines[2] or ""
    ip = lines[3] or ""
    if busy then
      return
    end
    if unitState == "active" then
      state = "on"
    else
      state = "off"
    end
    render()
  end)
  if not accepted then
    polling = false
  end
end

-- ── actions ──────────────────────────────────────────────────────────────────

local function setPower(on)
  if busy then
    return
  end
  busy = true
  state = "busy"
  detail = ""
  render()

  local action = on and "on" or "off"
  local accepted = noctalia.runAsync(shQuote(AWGQ) .. " " .. action, function(result)
    busy = false
    if result == nil or result.exitCode ~= 0 then
      local err = ""
      if result ~= nil then
        err = result.stderr
        if err == nil or err == "" then
          err = result.stdout
        end
      end
      detail = truncate(noctalia.string.trim(err or ""), 120)
      noctalia.notifyError(noctalia.tr("notify.title"), noctalia.tr("errors.toggle"))
    end
    poll()
  end)
  if not accepted then
    busy = false
    noctalia.notifyError(noctalia.tr("notify.title"), noctalia.tr("errors.toggle"))
    poll()
  end
end

function toggle()
  if busy then
    return
  end
  setPower(state ~= "on")
end

-- ── lifecycle ────────────────────────────────────────────────────────────────

noctalia.setUpdateInterval(REFRESH_MS)

function update()
  if busy or polling then
    return
  end
  poll()
end

function onClick()
  toggle()
end

function onRightClick()
  poll()
  local parts = { statusLabel() }
  if config ~= "" then
    table.insert(parts, config)
  end
  if ip ~= "" then
    table.insert(parts, "IP " .. ip)
  end
  noctalia.notify(noctalia.tr("notify.title"), table.concat(parts, " · "))
end

function onIpc(event, _payload)
  if event == "toggle" then
    toggle()
  elseif event == "on" then
    setPower(true)
  elseif event == "off" then
    setPower(false)
  elseif event == "refresh" then
    poll()
  end
end

render()
poll()
