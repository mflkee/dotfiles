--!nonstrict
-- OpenCode Go plan limits (rolling 5h / weekly / monthly) for the Noctalia bar.
--
-- OpenCode has no public API for plan limits, so the numbers are scraped from
-- the server-rendered dashboard page, exactly like the reference CLI
-- (opencode-go-usage-analyzer) does: the page carries a
-- <div data-slot="usage"> block whose text reads
--   "Rolling Usage85%Resets in 2h 15m Weekly Usage40%..."
-- Stripping tags gives the same string the Python tool feeds to its regex.
--
-- Credentials never come from Noctalia settings (settings.toml is 0644 and
-- world-readable): they are read from a 0600 JSON file
--   {"workspace_id": "...", "token": "..."}
-- or from the OPENCODE_GO_WORKSPACE / OPENCODE_GO_TOKEN env vars.

local DASHBOARD = "https://opencode.ai/workspace/%s/go"
local DEFAULT_CREDENTIALS = "~/.config/opencode-go/credentials.json"
local USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

-- Ayu's yellow: the palette has no warning role, so severity is spelled out.
local COLOR_WARN = "#e6b450"
local COLOR_MUTED = "on_surface_variant"

-- Order matters: each segment runs from its marker up to the next one.
local KINDS = {
  { marker = "Rolling Usage", label = "5h" },
  { marker = "Weekly Usage", label = "week" },
  { marker = "Monthly Usage", label = "month" },
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

-- ── credentials ──────────────────────────────────────────────────────────────

local function loadCredentials()
  local envWorkspace = noctalia.getenv("OPENCODE_GO_WORKSPACE")
  local envToken = noctalia.getenv("OPENCODE_GO_TOKEN")
  if type(envWorkspace) == "string" and envWorkspace ~= "" and type(envToken) == "string" and envToken ~= "" then
    return envWorkspace, envToken
  end

  local raw = noctalia.readFile(CREDENTIALS_PATH)
  if raw == nil then
    return nil
  end
  local decoded = noctalia.json.decode(raw)
  if type(decoded) ~= "table" then
    return nil
  end
  local workspace = decoded.workspace_id
  local token = decoded.token
  if type(workspace) ~= "string" or workspace == "" or type(token) ~= "string" or token == "" then
    return nil
  end
  return workspace, token
end

-- ── dashboard scraping ───────────────────────────────────────────────────────

-- Markers are matched as patterns so "RollingUsage" and "Rolling   Usage" both
-- survive the tag strip.
local function findMarker(text, marker)
  return text:find(marker:gsub(" ", "%%s+"))
end

local function usageText(html)
  local start = html:find('data-slot="usage"', 1, true)
  if start == nil then
    return nil
  end
  -- The block runs until the next marked section (or 4 KB, whichever is first)
  -- so a trailing dashboard section cannot leak into the numbers.
  local block = html:sub(start, start + 4000)
  local nextSlot = block:find('data-slot=', 2, true)
  if nextSlot ~= nil then
    block = block:sub(1, nextSlot - 1)
  end
  block = block:gsub("<[^>]*>", "")
  block = block:gsub("<[^<>]*$", "") -- the cut can leave a half-open tag behind
  block = block:gsub("%s+", " ")
  return block
end

local function parseUsage(text)
  local parsed = {}
  for index, kind in ipairs(KINDS) do
    local from = findMarker(text, kind.marker)
    if from ~= nil then
      local to = nil
      if index < #KINDS then
        to = findMarker(text, KINDS[index + 1].marker)
        if to ~= nil and to <= from then
          to = nil
        end
      end
      local segment = text:sub(from, to ~= nil and (to - 1) or nil)
      local percent = segment:match("(%d+)%%")
      if percent ~= nil then
        -- Bounded on purpose: words, digits and separators only, so a stray
        -- trailing section cannot be swallowed into "Resets in ...".
        local reset = segment:match("Resets%s+in%s+([%w][%w%d%.%,:%s%-]*%w)")
        table.insert(parsed, {
          label = kind.label,
          percent = tonumber(percent),
          reset = reset ~= nil and noctalia.string.trim(reset) or "",
        })
      end
    end
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

local function render()
  if status == "ok" and #readings > 0 then
    local top = worst(readings)
    if DISPLAY == "all" then
      barWidget.setText(summary())
    else
      barWidget.setText(PREFIX .. " " .. top.percent .. "%")
    end
    if top.percent >= 90 then
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

local function finish(text)
  if text == nil then
    fail("error", "на странице нет блока data-slot=\"usage\"")
    return
  end
  local parsed = parseUsage(text)
  if #parsed == 0 then
    fail("error", "не удалось прочитать лимиты")
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
  local workspace, token = loadCredentials()
  if workspace == nil then
    fail("setup", "нет учётных данных: " .. CREDENTIALS_PATH)
    return
  end

  busy = true
  local started = noctalia.http({
    url = string.format(DASHBOARD, workspace),
    method = "GET",
    follow_redirects = true,
    headers = {
      "Cookie: auth=" .. token .. "; oc_locale=en",
      "User-Agent: " .. USER_AGENT,
      "Accept: text/html",
    },
  }, function(response)
    busy = false
    if response == nil or not response.ok then
      fail("network", "сетевая ошибка")
      return
    end
    if response.status ~= 200 then
      fail("network", "HTTP " .. tostring(response.status))
      return
    end
    local body = response.body or ""
    if body:find("Continue with Google", 1, true) then
      fail("auth", "токен не принят — обнови auth-cookie")
      return
    end
    finish(usageText(body))
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
