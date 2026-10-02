--!nonstrict
-- OpenCode Go plan limits (rolling 5h / weekly / monthly) for the Noctalia bar.
--
-- Data source: GET https://opencode.ai/console/api/go/status - the same oRPC
-- endpoint the web dashboard calls. It answers with plain JSON:
--
--   {"access":{"endsAt":"...","meters":{
--      "fiveHour":{"resetsAt":null,"limitMicroCents":"1200000000","usedMicroCents":"0"},
--      "week":   {"resetsAt":"2026-09-28T00:00:00.000Z","limitMicroCents":"3000000000", ...},
--      "month":  {"limitMicroCents":"6000000000","usedMicroCents":"3000000000"}}}}
--
-- Meters are money budgets, not request counts, so the percentage is
-- used/limit of the spend cap.
--
-- v1.2: несколько аккаунтов (A/B). Активный аккаунт читается из
--   ~/.config/opencode-go/current
-- creds активного аккаунта — из ~/.config/opencode-go/credentials.json
-- (копию активного аккаунта обновляет opencode-go-auth). Клик по виджету
-- запускает `opencode-go-auth use <следующий>` — переключение занимает ~1с.

local API = "https://opencode.ai/console/api/go/status"
local BASE_DIR = noctalia.expandPath("~/.config/opencode-go")
local DEFAULT_CREDENTIALS = BASE_DIR .. "/credentials.json"
local CURRENT_FILE = BASE_DIR .. "/current"
local ACCOUNTS_DIR = BASE_DIR .. "/accounts"
local USER_AGENT = "opencode-go-usage/1.2 (noctalia bar widget)"

-- Ayu's yellow: the palette has no warning role, so severity is spelled out.
local COLOR_WARN = "#e6b450"
local COLOR_MUTED = "on_surface_variant"
local COLOR_BUSY = "primary"

-- Order matters: this is the order the dashboard shows and the order the bar
-- uses in "all" mode.
local METERS = {
  { key = "fiveHour", label = "5h" },
  { key = "week", label = "week" },
  { key = "month", label = "month" },
}

local function setting(key, fallback)
  local value = noctalia.getConfig(key)
  if value == nil then
    return fallback
  end
  return value
end

local PREFIX = tostring(setting("label", "OC"))
local DISPLAY = tostring(setting("display", "worst"))
local CLICK_ACTION = tostring(setting("click_action", "switch"))
local SHOW_ACCOUNT = setting("show_account", true) ~= false
local CREDENTIALS_PATH = noctalia.expandPath(tostring(setting("credentials_file", DEFAULT_CREDENTIALS)))
local REFRESH_SECONDS = (tonumber(setting("refresh_minutes", 5)) or 5) * 60

local readings = {}
local status = "setup"
local detail = ""
local refreshed = false
local lastAttempt = 0
local busy = false
local manual = false
local loadedExpires = nil
local activeAccount = ""
local transitionalAccount = ""
local switchBusy = false

-- render определён ниже (секция rendering), но зовётся из runSwitch(),
-- который объявлен раньше по тексту. Без форвард-декларации ссылка внутри
-- runSwitch резолвилась в ГЛОБАЛЬНУЮ render (nil) → клик по виджету падал
-- с "attempt to call a nil value" и аккаунты не переключались.
local render

-- ── account state ────────────────────────────────────────────────────────────

local function loadActiveAccount()
  local raw = noctalia.readFile(CURRENT_FILE)
  if raw ~= nil then
    local n = tostring(raw):gsub("%s", "")
    if n ~= "" then
      activeAccount = n
      return
    end
  end
  activeAccount = ""
end

local function accountLabel()
  if transitionalAccount ~= "" then
    return "<span>" .. transitionalAccount:upper() .. "</span>"
  end
  if activeAccount ~= "" then
    return activeAccount:upper()
  end
  return PREFIX
end

-- Следующий за активным аккаунт из списка accounts/*.json; fallback a->b/b->a.
local function nextAccount()
  local entries = noctalia.listDir(ACCOUNTS_DIR)
  local names = {}
  if type(entries) == "table" then
    for _, entry in ipairs(entries) do
      local n = entry
      if type(entry) == "table" then
        n = entry.name
      end
      if type(n) == "string" then
        local name = n:gsub("%.json$", "")
        if name ~= n then
          table.insert(names, name)
        end
      end
    end
  end
  if #names < 2 then
    -- Fallback: жёсткая пара a/b. API v5.2.1 — fileExists (noctalia.exists нет).
    names = {}
    if noctalia.fileExists(ACCOUNTS_DIR .. "/a.json") then table.insert(names, "a") end
    if noctalia.fileExists(ACCOUNTS_DIR .. "/b.json") then table.insert(names, "b") end
  end
  table.sort(names)
  if #names < 2 then
    return nil
  end
  for _, name in ipairs(names) do
    if name ~= activeAccount then
      return name
    end
  end
  return names[1]
end

local function runSwitch(target)
  if switchBusy then
    return
  end
  switchBusy = true
  transitionalAccount = target
  status = "ok"
  detail = "переключаюсь на " .. target:upper() .. "…"
  render()

  local tool = noctalia.expandPath("~/.local/bin/opencode-go-auth")
  local command = "'" .. tool .. "' use '" .. target .. "' 2>/dev/null"
  local function onLine(line)
    if line ~= nil and tostring(line) ~= "" then
      detail = tostring(line)
    end
  end
  if not noctalia.runStream(command, onLine) then
    switchBusy = false
    transitionalAccount = ""
    noctalia.notifyError("OpenCode Go", "не удалось запустить opencode-go-auth")
    render()
    return
  end
  -- runStream асинхронный; финальное состояние придёт через onIpc("refresh"),
  -- который вызовет сам скрипт. Дополнительно пробуем обновиться через 2с.
end

-- ── credentials ──────────────────────────────────────────────────────────────

local function loadCredentials()
  local raw = noctalia.readFile(CREDENTIALS_PATH)
  if raw == nil then
    return nil
  end
  local decoded = noctalia.json.decode(raw)
  if type(decoded) ~= "table" then
    return nil
  end
  local org = decoded.org_id
  local token = decoded.access_token
  if type(org) ~= "string" or org == "" or type(token) ~= "string" or token == "" then
    return nil
  end
  return org, token, tonumber(decoded.expires_at)
end

-- ── parsing ──────────────────────────────────────────────────────────────────

-- Days since 1970-01-01 for a proleptic Gregorian date. The API sends UTC and
-- os.time only speaks local time, so the countdown is done in UTC calendar
-- seconds instead: identical in every timezone and free of DST edges.
local function daysFromCivil(year, month, day)
  year = month <= 2 and year - 1 or year
  local era = math.floor(year / 400)
  local yearOfEra = year - era * 400
  local shifted = month + (month > 2 and -3 or 9)
  local dayOfYear = math.floor((153 * shifted + 2) / 5) + day - 1
  local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
  return era * 146097 + dayOfEra - 719468
end

-- UTC calendar seconds for a "....-..-..T..:..:..(.mmm)?Z" stamp, or nil.
local function isoToUtc(text)
  if type(text) ~= "string" then
    return nil
  end
  local year, month, day, hour, minute, second =
    text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if year == nil then
    return nil
  end
  return daysFromCivil(tonumber(year), tonumber(month), tonumber(day)) * 86400
    + tonumber(hour) * 3600 + tonumber(minute) * 60 + tonumber(second)
end

local function nowUtc()
  local parts = os.date("!*t", os.time())
  return daysFromCivil(parts.year, parts.month, parts.day) * 86400
    + parts.hour * 3600 + parts.min * 60 + parts.sec
end

local function tonum(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    return tonumber(value)
  end
  return nil
end

-- Countdown to a reset, capped at 99d so a far-future date cannot push the
-- tooltip row out of view.
local function countdown(utcText, now)
  local target = isoToUtc(utcText)
  if target == nil then
    return ""
  end
  local left = math.floor(target - now)
  if left <= 0 then
    return "due"
  end
  if left > 99 * 86400 then
    return ">99d"
  end
  local days = math.floor(left / 86400)
  local hours = math.floor((left % 86400) / 3600)
  local minutes = math.floor((left % 3600) / 60)
  if days > 0 then
    return string.format("%dd %dh", days, hours)
  end
  if hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  end
  return string.format("%dm", minutes)
end

local function parseStatus(body, now)
  local decoded = noctalia.json.decode(body)
  if type(decoded) ~= "table" then
    return nil, "ответ не JSON"
  end
  local access = decoded.access
  if type(access) ~= "table" or type(access.meters) ~= "table" then
    if type(decoded._tag) == "string" then
      return nil, "console: " .. decoded._tag
    end
    return nil, "в ответе нет access.meters"
  end

  local parsed = {}
  for _, meter in ipairs(METERS) do
    local source = access.meters[meter.key]
    if type(source) == "table" then
      local used = tonum(source.usedMicroCents)
      local limit = tonum(source.limitMicroCents)
      if used ~= nil and limit ~= nil and limit > 0 then
        local percent = math.floor(used * 100 / limit)
        if percent > 100 then
          percent = 100
        end
        local reset = countdown(source.resetsAt, now)
        if reset == "" and meter.key == "month" then
          reset = countdown(access.endsAt, now)
        end
        table.insert(parsed, {
          label = meter.label,
          percent = percent,
          reset = reset,
        })
      end
    end
  end
  if #parsed == 0 then
    return nil, "нет meter'ов с числами"
  end
  return parsed
end

-- ── rendering ────────────────────────────────────────────────────────────────

local function worst(list)
  local top = nil
  for _, reading in ipairs(list) do
    if top == nil or reading.percent > top.percent then
      top = reading
    end
  end
  return top
end

local function summary()
  local parts = {}
  for _, reading in ipairs(readings) do
    table.insert(parts, reading.label .. " " .. reading.percent .. "%")
  end
  return table.concat(parts, " · ")
end

local function expiringSoon()
  local expires = tonumber(loadedExpires)
  if expires == nil then
    return false
  end
  return expires - os.time() < 3 * 86400
end

render = function()
  if status == "ok" and #readings > 0 then
    local top = worst(readings)
    local prefix = SHOW_ACCOUNT and accountLabel() or PREFIX
    if DISPLAY == "all" then
      barWidget.setText(prefix .. " " .. summary())
    else
      barWidget.setText(prefix .. " " .. top.percent .. "%")
    end
    if switchBusy then
      barWidget.setColor(COLOR_BUSY)
    elseif expiringSoon() then
      barWidget.setColor(COLOR_WARN, "script")
    elseif top.percent >= 90 then
      barWidget.setColor("error")
    elseif top.percent > 50 then
      barWidget.setColor(COLOR_WARN, "script")
    else
      barWidget.setColor("success")
    end

    local rows = {}
    table.insert(rows, { key = "аккаунт", value = accountLabel() })
    for _, reading in ipairs(readings) do
      local value = reading.percent .. "%"
      if reading.reset ~= "" then
        value = value .. "  ·  " .. reading.reset
      end
      table.insert(rows, { key = reading.label, value = value })
    end
    if switchBusy then
      table.insert(rows, { key = "status", value = detail })
    end
    if expiringSoon() then
      table.insert(rows, { key = "token", value = "истекает — opencode-go-auth login" })
    end
    if refreshed then
      table.insert(rows, { key = "updated", value = noctalia.formatTime("%H:%M") })
    end
    if CLICK_ACTION == "switch" then
      table.insert(rows, { key = "клик", value = "переключить аккаунт" })
    end
    barWidget.setTooltip(rows)
    return
  end

  if status == "setup" then
    barWidget.setText(accountLabel() .. " ⚙")
  elseif status == "auth" then
    barWidget.setText(accountLabel() .. " ⚠")
  else
    barWidget.setText(accountLabel() .. " !")
  end
  barWidget.setColor(COLOR_MUTED)
  barWidget.setTooltip({ { key = "OpenCode Go", value = detail } })
end

local function fail(nextStatus, message)
  status = nextStatus
  detail = message
  if manual then
    noctalia.notifyError("OpenCode Go", message)
    manual = false
  end
  render()
end

-- ── fetching ─────────────────────────────────────────────────────────────────

local function finish(body)
  local parsed, err = parseStatus(body, nowUtc())
  if parsed == nil then
    fail(err == "console: Unauthorized" and "auth" or "error", err or "не удалось прочитать лимиты")
    return
  end
  readings = parsed
  status = "ok"
  detail = ""
  refreshed = true
  transitionalAccount = ""
  switchBusy = false
  render()
  if manual then
    noctalia.notify("OpenCode Go", accountLabel() .. " " .. summary())
    manual = false
  end
end

local function fetch()
  if busy then
    return
  end
  lastAttempt = os.time()
  loadActiveAccount()
  local org, token, expires = loadCredentials()
  loadedExpires = expires
  if org == nil then
    fail("setup", "нет учётных данных: " .. CREDENTIALS_PATH .. " (opencode-go-auth login)")
    return
  end

  busy = true
  local started = noctalia.http({
    url = API,
    method = "GET",
    follow_redirects = true,
    headers = {
      "Authorization: Bearer " .. token,
      "x-org-id: " .. org,
      "Accept: application/json",
      "User-Agent: " .. USER_AGENT,
    },
  }, function(response)
    busy = false
    if response == nil or not response.ok then
      fail("network", "сетевая ошибка")
      return
    end
    if response.status == 401 or response.status == 403 then
      fail("auth", "токен отвергнут (HTTP " .. tostring(response.status) .. ") — opencode-go-auth login")
      return
    end
    if response.status ~= 200 then
      fail("network", "HTTP " .. tostring(response.status))
      return
    end
    finish(response.body or "")
  end)

  if not started then
    busy = false
    fail("error", "запрос не запущен")
  end
end

-- ── lifecycle ────────────────────────────────────────────────────────────────

noctalia.setUpdateInterval(30000)

function update()
  local now = os.time()
  if now - lastAttempt >= REFRESH_SECONDS then
    fetch()
  end
end

function onClick()
  if CLICK_ACTION == "refresh" then
    manual = true
    fetch()
    return
  end
  local target = nextAccount()
  if target == nil then
    noctalia.notifyError("OpenCode Go", "настроен только один аккаунт — добавь второй: opencode-go-auth login --account b")
    return
  end
  if target == activeAccount then
    manual = true
    fetch()
    return
  end
  runSwitch(target)
end

function onIpc(event)
  if event == "refresh" then
    manual = true
    fetch()
  elseif type(event) == "string" and event:match("^switched:") then
    transitionalAccount = event:match("^switched:(.*)$")
    fetch()
  end
end

loadActiveAccount()
render()
fetch()

