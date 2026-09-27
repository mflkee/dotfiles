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
-- used/limit of the spend cap. Auth is the OpenCode CLI's OAuth device token
-- (Authorization: Bearer <access_token> + x-org-id: <org_id>), produced by
--   opencode-go-auth login
-- Credentials never come from Noctalia settings (settings.toml is 0644 and
-- world-readable); they are read from a 0600 JSON file
--   {"org_id": "wrk_...", "access_token": "...", "expires_at": 1793104191}
-- or from the OPENCODE_GO_ORG / OPENCODE_GO_TOKEN env vars. expires_at is only
-- used for the "token expiring" warning - the token is valid for 30 days and
-- there is no working renewal, so re-running the login script is the fix.

local API = "https://opencode.ai/console/api/go/status"
local DEFAULT_CREDENTIALS = "~/.config/opencode-go/credentials.json"
local USER_AGENT = "opencode-go-usage/1.1 (noctalia bar widget)"

-- Ayu's yellow: the palette has no warning role, so severity is spelled out.
local COLOR_WARN = "#e6b450"
local COLOR_MUTED = "on_surface_variant"

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

-- ── credentials ──────────────────────────────────────────────────────────────

local function loadCredentials()
  local envOrg = noctalia.getenv("OPENCODE_GO_ORG")
  local envToken = noctalia.getenv("OPENCODE_GO_TOKEN")
  if type(envOrg) == "string" and envOrg ~= "" and type(envToken) == "string" and envToken ~= "" then
    return envOrg, envToken, nil
  end

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

-- "2026-09-28T00:00:00.000Z" -> epoch seconds. Only the Z form the API emits is
-- accepted; anything else returns nil and the caller falls back to the renewal
-- date. Hand-rolled because the plugin API has no date parser.
local function isoToEpoch(text)
  if type(text) ~= "string" then
    return nil
  end
  local year, month, day, hour, minute, second =
    text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if year == nil then
    return nil
  end
  local days = os.difftime(0, os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(minute),
    sec = tonumber(second),
  }))
  if days == nil then
    return nil
  end
  -- os.time reads the table as local time; the API is UTC, so shift the result.
  return days - os.difftime(0, os.date("*t", 0))
end

-- Micro-cents arrive as strings; anything unparsable must not become NaN in the
-- bar, so a bad number drops the meter instead of rendering "nan%".
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
-- tooltip row out of view. Uses localtime, matching how os.time reads the table.
local function countdown(utcText, now)
  local target = isoToEpoch(utcText)
  if target == nil then
    return ""
  end
  local left = math.floor(target - now)
  if left <= 0 then
    return "due"
  end
  local days = math.floor(left / 86400)
  local hours = math.floor((left % 86400) / 3600)
  local minutes = math.floor((left % 3600) / 60)
  if days > 99 then
    return ">99d"
  end
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
    -- 401/403 bodies are {"_tag":"Unauthorized"} and have no access block.
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
        -- Rolling 5h has no resetsAt until it is first touched; the monthly
        -- meter renews with the subscription instead of resetting weekly.
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

-- Warns before the token dies rather than after: the renewal is a manual
-- browser approval, so a silent 401 a day later is worse than a yellow bar.
local function expiringSoon()
  local expires = tonumber(loadedExpires)
  if expires == nil then
    return false
  end
  return expires - os.time() < 3 * 86400
end

local function render()
  if status == "ok" and #readings > 0 then
    local top = worst(readings)
    if DISPLAY == "all" then
      barWidget.setText(summary())
    else
      barWidget.setText(PREFIX .. " " .. top.percent .. "%")
    end
    if expiringSoon() then
      barWidget.setColor(COLOR_WARN, "script")
    elseif top.percent >= 90 then
      barWidget.setColor("error")
    elseif top.percent > 50 then
      barWidget.setColor(COLOR_WARN, "script")
    else
      barWidget.setColor("success")
    end

    local rows = {}
    for _, reading in ipairs(readings) do
      local value = reading.percent .. "%"
      if reading.reset ~= "" then
        value = value .. "  ·  " .. reading.reset
      end
      table.insert(rows, { key = reading.label, value = value })
    end
    if expiringSoon() then
      table.insert(rows, { key = "token", value = "истекает — opencode-go-auth login" })
    end
    if refreshed then
      table.insert(rows, { key = "updated", value = noctalia.formatTime("%H:%M") })
    end
    barWidget.setTooltip(rows)
    return
  end

  if status == "setup" then
    barWidget.setText(PREFIX .. " ⚙")
  elseif status == "auth" then
    barWidget.setText(PREFIX .. " ⚠")
  else
    barWidget.setText(PREFIX .. " !")
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
  local parsed, err = parseStatus(body, os.time())
  if parsed == nil then
    -- A tag of Unauthorized/Forbidden means the token, not the format.
    fail(err == "console: Unauthorized" and "auth" or "error", err or "не удалось прочитать лимиты")
    return
  end
  readings = parsed
  status = "ok"
  detail = ""
  refreshed = true
  render()
  if manual then
    noctalia.notify("OpenCode Go", summary())
    manual = false
  end
end

local function fetch()
  if busy then
    return
  end
  lastAttempt = os.time()
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
  manual = true
  fetch()
end

function onIpc(event)
  if event == "refresh" then
    manual = true
    fetch()
  end
end

render()
fetch()
