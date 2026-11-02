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
--
-- v1.3: метка «переключаюсь» — обычный текст (B…). Раньше в ней был
--   <span>B</span>: бар не понимает разметку и печатал теги как есть, а если
--   после переключения fetch падал (нет подписки/токен/сеть), transitional
--   аккаунт не сбрасывался и теги висели в баре, пока не придёт удачный ответ.
--   Теперь состояние переключения закрывается по exit-коду runAsync и по
--   таймауту-сторожу в update(), поэтому «залипнуть» не может.

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
local AUTO_SWITCH = tostring(setting("auto_switch", "auth"))
local SHOW_ACCOUNT = setting("show_account", true) ~= false
local CREDENTIALS_PATH = noctalia.expandPath(tostring(setting("credentials_file", DEFAULT_CREDENTIALS)))
local REFRESH_SECONDS = (tonumber(setting("refresh_minutes", 5)) or 5) * 60

local readings = {}
local status = "setup"
local detail = ""
local refreshed = false
local updatedAt = 0
local lastAttempt = 0
local busy = false
local manual = false
local loadedExpires = nil
local activeAccount = ""
local transitionalAccount = ""
local switchBusy = false
local switchStartedAt = 0
local staleAt = 0
local pendingFetch = false
local lastSeen = {}
local autoBusy = false
local lastAutoAt = 0

-- render определён ниже (секция rendering), но зовётся из runSwitch(),
-- который объявлен раньше по тексту. Без форвард-декларации ссылка внутри
-- runSwitch резолвилась в ГЛОБАЛЬНУЮ render (nil) → клик по виджету падал
-- с "attempt to call a nil value" и аккаунты не переключались.
-- То же самое для fetch: runSwitch завершает переключение его вызовом.
local render
local fetch

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

-- Метаданные аккаунта из accounts/<name>.json: срок токена, метка (Kimi /
-- Mfokinors) и email (заполняется при login через /console/api/user).
local function accountMeta(name)
  local raw = noctalia.readFile(ACCOUNTS_DIR .. "/" .. name .. ".json")
  if raw == nil then
    return nil
  end
  local decoded = noctalia.json.decode(raw)
  if type(decoded) ~= "table" then
    return nil
  end
  return {
    expires = tonumber(decoded.expires_at),
    label = type(decoded.label) == "string" and decoded.label or "",
    email = type(decoded.email) == "string" and decoded.email or "",
  }
end

-- Срок действия токена аккаунта: nil, если файла нет или в нём нет expires_at.
local function accountExpires(name)
  local meta = accountMeta(name)
  if meta == nil then
    return nil
  end
  return meta.expires
end

local function tokenExpired(name)
  local expires = accountExpires(name)
  return expires ~= nil and expires > 0 and expires <= os.time()
end

-- Как аккаунт зовут в баре: метка из accounts/<name>.json (`opencode-go-auth
-- label a Kimi`), иначе email без домена, иначе просто A/B.
local function accountDisplay(name)
  local meta = accountMeta(name)
  if meta ~= nil then
    if meta.label ~= "" then
      return meta.label
    end
    if meta.email ~= "" then
      return (meta.email:gsub("@.*$", ""))
    end
  end
  return name:upper()
end

local function accountLabel()
  if transitionalAccount ~= "" then
    -- Обычный текст: бар НЕ понимает разметку, и <span>…</span> печатался
    -- в строке как есть. Многоточие + цвет COLOR_BUSY и так читаются
    -- как «переключаюсь».
    return accountDisplay(transitionalAccount) .. "…"
  end
  if activeAccount ~= "" then
    return accountDisplay(activeAccount)
  end
  return PREFIX
end

-- Все аккаунты из accounts/*.json (fallback a/b). Отсортированы по имени.
local function accountNames()
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
  return names
end

-- Строки тултипа по всем аккаунтам: кто это, жив ли токен и последние цифры.
local function accountRows(rows)
  for _, name in ipairs(accountNames()) do
    local meta = accountMeta(name)
    local marker = name == activeAccount and "•" or " "
    local value
    if meta == nil then
      value = "нет токена"
    elseif tokenExpired(name) then
      value = "токен истёк " .. os.date("%d.%m", meta.expires)
    elseif lastSeen[name] ~= nil then
      value = lastSeen[name].percent .. "%"
      if lastSeen[name].reset ~= "" then
        value = value .. " · до " .. lastSeen[name].reset
      end
    elseif meta.expires ~= nil and meta.expires > 0 then
      value = "токен жив до " .. os.date("%d.%m", meta.expires)
    else
      value = "токен без срока"
    end
    table.insert(rows, {
      key = marker .. " " .. accountDisplay(name) .. " (" .. name .. ")",
      value = value,
    })
  end
end

-- Следующий за активным аккаунт из списка accounts/*.json; fallback a->b/b->a.
-- Возвращает name или nil + причину. Протухшие токены пропускаются: раньше
-- клик уводил виджет на мёртвый аккаунт (401), и бар показывал вместо цифр
-- голую метку с ⚠.
local function nextAccount()
  local names = accountNames()
  if #names < 2 then
    return nil, "настроен только один аккаунт — добавь второй: opencode-go-auth login --account b"
  end

  local usable, expired = {}, {}
  for _, name in ipairs(names) do
    if tokenExpired(name) then
      table.insert(expired, name)
    else
      table.insert(usable, name)
    end
  end
  if #usable == 0 then
    return nil, "у всех аккаунтов протухли токены — opencode-go-auth login --account "
      .. table.concat(expired, "/")
  end
  for _, name in ipairs(usable) do
    if name ~= activeAccount then
      return name
    end
  end
  return usable[1]
end

-- Код возврата из результата runAsync. Разные версии API отдают либо число в
-- exitCode/exit_code, либо булево; nil/true = успех.
local function exitCodeOf(result)
  if type(result) == "table" then
    local code = tonumber(result.exitCode) or tonumber(result.exit_code)
    if code ~= nil then
      return code
    end
    if result.success == false then
      return 1
    end
    return 0
  end
  if result == false then
    return 1
  end
  return 0
end

local function resultText(result)
  if type(result) ~= "table" then
    return ""
  end
  local text = result.stderr
  if type(text) ~= "string" or text == "" then
    text = result.stdout
  end
  if type(text) ~= "string" then
    return ""
  end
  return (text:gsub("%s+$", ""))
end

-- Закрыть состояние переключения: без этого метка «переключаюсь» (и раньше —
-- теги <span>) оставалась в баре, если после `use` не приходило удачного
-- ответа API (нет подписки на аккаунте, протухший токен, сеть).
local function endSwitch()
  switchBusy = false
  switchStartedAt = 0
  transitionalAccount = ""
end

local function runSwitch(target)
  if switchBusy then
    return
  end
  switchBusy = true
  switchStartedAt = os.time()
  transitionalAccount = target
  status = "ok"
  detail = "переключаюсь на " .. target:upper() .. "…"
  render()

  local tool = noctalia.expandPath("~/.local/bin/opencode-go-auth")
  local command = "'" .. tool .. "' use '" .. target .. "' 2>&1"
  local function done(result)
    endSwitch()
    loadActiveAccount()
    if exitCodeOf(result) ~= 0 then
      local text = resultText(result)
      noctalia.notifyError("OpenCode Go", "не удалось переключить на " .. target:upper()
        .. (text ~= "" and (": " .. text) or ""))
    end
    -- Перечитываем лимиты уже нового аккаунта. Если запрос ещё летит,
    -- fetch отложится (pendingFetch), а не потеряется.
    fetch()
    render()
  end
  if not noctalia.runAsync(command, done, 30000) then
    endSwitch()
    noctalia.notifyError("OpenCode Go", "не удалось запустить opencode-go-auth")
    render()
  end
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
  if autoBusy then
    local who = activeAccount ~= "" and accountDisplay(activeAccount) or PREFIX
    barWidget.setText(who .. " …")
    barWidget.setColor(COLOR_BUSY)
    barWidget.setTooltip({ { key = "OpenCode Go", value = detail } })
    return
  end

  if #readings > 0 and (status == "ok" or status == "stale") then
    local top = worst(readings)
    local prefix = SHOW_ACCOUNT and accountLabel() or PREFIX
    if DISPLAY == "all" then
      barWidget.setText(prefix .. " " .. summary())
    else
      barWidget.setText(prefix .. " " .. top.percent .. "%")
    end
    if switchBusy then
      barWidget.setColor(COLOR_BUSY)
    elseif status == "stale" then
      barWidget.setColor(COLOR_MUTED)
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
    accountRows(rows)
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
    if status == "stale" then
      table.insert(rows, { key = "связь", value = "нет свежих данных · последние в " .. os.date("%H:%M", updatedAt) })
    end
    if expiringSoon() then
      table.insert(rows, { key = "token", value = "истекает — opencode-go-auth login" })
    end
    if refreshed then
      table.insert(rows, { key = "updated", value = os.date("%H:%M", updatedAt) })
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
  local rows = { { key = "OpenCode Go", value = detail } }
  if #accountNames() > 0 then
    accountRows(rows)
  end
  barWidget.setTooltip(rows)
end

local function fail(nextStatus, message)
  -- Любой финальный ответ закрывает переключение: иначе метка «переключаюсь»
  -- остаётся в баре навсегда, если новый аккаунт без подписки / токен отвергнут.
  endSwitch()
  if #readings > 0 and (nextStatus == "network" or nextStatus == "error") then
    -- Сеть/сервер отвалились: не теряем последние удачные цифры, показываем
    -- их приглушённо, пока не придёт свежий ответ.
    status = "stale"
    staleAt = os.time()
  else
    status = nextStatus
  end
  detail = message
  if manual then
    noctalia.notifyError("OpenCode Go", message)
    manual = false
  end
  render()
end

-- ── auto-failover ────────────────────────────────────────────────────────────
--
-- Аккаунт кончился (токен умер или лимит выбран) — уходим на живой. Решение
-- принимает `opencode-go-auth auto`: он проверяет кандидатов по API, поэтому
-- виджет не прыгает на такой же мёртвый аккаунт. Настройка auto_switch:
--   off     — никогда,
--   auth    — только когда консоль отвергает токен (401/403/истёк срок),
--   always  — ещё и когда лимит выбран на 100%.
-- Кулдаун 60 с, чтобы 401 на обоих аккаунтах не превращался в карусель.

local function runAutoSwitch(reason)
  if AUTO_SWITCH == "off" or autoBusy or switchBusy then
    return false
  end
  if AUTO_SWITCH == "auth" and reason ~= "auth" then
    return false
  end
  if os.time() - lastAutoAt < 60 then
    return false
  end

  autoBusy = true
  lastAutoAt = os.time()
  local before = activeAccount
  detail = "подбираю живой аккаунт…"
  render()

  local tool = noctalia.expandPath("~/.local/bin/opencode-go-auth")
  local command = "'" .. tool .. "' auto 2>&1"
  local function done(result)
    autoBusy = false
    loadActiveAccount()
    if exitCodeOf(result) ~= 0 then
      local text = resultText(result)
      fail("auth", text ~= "" and text or "все аккаунты недоступны — нужен opencode-go-auth login")
      return
    end
    if activeAccount ~= "" and activeAccount ~= before then
      noctalia.notify("OpenCode Go",
        "переключил " .. accountDisplay(before) .. " → " .. accountDisplay(activeAccount))
    end
    fetch()
    render()
  end
  if not noctalia.runAsync(command, done, 45000) then
    autoBusy = false
    fail("auth", "не удалось запустить opencode-go-auth auto")
    return false
  end
  return true
end

-- ── fetching ─────────────────────────────────────────────────────────────────

local function finish(body)
  local parsed, err = parseStatus(body, nowUtc())
  if parsed == nil then
    if err == "console: Unauthorized" and runAutoSwitch("auth") then
      return
    end
    fail(err == "console: Unauthorized" and "auth" or "error", err or "не удалось прочитать лимиты")
    return
  end
  readings = parsed
  local top = worst(readings)
  if top ~= nil and activeAccount ~= "" then
    lastSeen[activeAccount] = { percent = top.percent, reset = top.reset }
  end
  status = "ok"
  detail = ""
  refreshed = true
  updatedAt = os.time()
  staleAt = 0
  endSwitch()
  -- Лимит выбран на 100% (месяц/неделя/5ч) — если разрешено, уходим на второй
  -- аккаунт. Решение за скриптом: он проверит, что там действительно есть чем
  -- платить, иначе оставит всё как есть.
  if top ~= nil and top.percent >= 100 and runAutoSwitch("quota") then
    return
  end
  render()
  if manual then
    noctalia.notify("OpenCode Go", accountLabel() .. " " .. summary())
    manual = false
  end
end

fetch = function()
  if busy then
    -- Переключение закончилось, пока летел запрос: не теряем обновление.
    pendingFetch = true
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
  -- Срок токена известен локально — не ждём 401 от API, а сразу уходим на
  -- живой аккаунт (если он есть и авто-переключение разрешено).
  if activeAccount ~= "" and tokenExpired(activeAccount) and runAutoSwitch("auth") then
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
    elseif response.status == 401 or response.status == 403 then
      if not runAutoSwitch("auth") then
        fail("auth", "токен отвергнут (HTTP " .. tostring(response.status) .. ") — opencode-go-auth login")
      end
    elseif response.status ~= 200 then
      fail("network", "HTTP " .. tostring(response.status))
    else
      finish(response.body or "")
    end
    if pendingFetch then
      pendingFetch = false
      fetch()
    end
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
  -- Сторож переключения: runAsync может не позвать callback (зависший процесс,
  -- таймаут не сработал) — не держим метку «переключаюсь» дольше 30 секунд.
  if switchBusy and switchStartedAt > 0 and now - switchStartedAt > 30 then
    endSwitch()
    render()
  end
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
  -- Один аккаунт — переключать некуда: клик просто обновляет цифры.
  if #accountNames() < 2 then
    manual = true
    fetch()
    return
  end
  local target, reason = nextAccount()
  if target == nil then
    noctalia.notifyError("OpenCode Go", reason or "некуда переключаться")
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
    switchBusy = true
    switchStartedAt = os.time()
    fetch()
  end
end

loadActiveAccount()
render()
fetch()

