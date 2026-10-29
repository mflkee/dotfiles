-- Standalone harness for usage.luau (Noctalia OpenCode Go widget).
-- Run: lua5.4 /tmp/opencode/test_usage.lua
-- Stubs the `noctalia` API + `barWidget`, feeds canned HTTP responses and
-- asserts on what the widget renders. No running shell required.

local PLUGIN = os.getenv("PLUGIN") or (os.getenv("HOME") .. "/dotfiles/dot_local/share/noctalia/plugins/opencode-go-usage/usage.luau")
if not io.open(PLUGIN) then PLUGIN = os.getenv("HOME") .. "/.local/share/noctalia/plugins/opencode-go-usage/usage.luau" end

-- ── mini JSON decoder (objects/arrays/strings/numbers/bool/null) ─────────────
local function json_decode(s)
  local pos = 1
  local function skip() while true do local c=s:sub(pos,pos); if c==" " or c=="\n" or c=="\t" or c=="\r" then pos=pos+1 else break end end end
  local parse_value
  local function parse_string()
    pos=pos+1; local out={}
    while true do
      local c=s:sub(pos,pos)
      if c=="" then error("unterminated string") end
      if c=='"' then pos=pos+1; break end
      if c=="\\" then
        local n=s:sub(pos+1,pos+1)
        if n=='"' or n=="\\" or n=="/" then out[#out+1]=n; pos=pos+2
        elseif n=="n" then out[#out+1]="\n"; pos=pos+2
        elseif n=="t" then out[#out+1]="\t"; pos=pos+2
        elseif n=="r" then out[#out+1]="\r"; pos=pos+2
        elseif n=="b" then out[#out+1]="\b"; pos=pos+2
        elseif n=="f" then out[#out+1]="\f"; pos=pos+2
        elseif n=="u" then out[#out+1]=utf8.char(tonumber(s:sub(pos+2,pos+5),16)); pos=pos+6
        else error("bad escape") end
      else out[#out+1]=c; pos=pos+1 end
    end
    return table.concat(out)
  end
  local function parse_number()
    local a,e = s:find("-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    local num = tonumber(s:sub(a,e)); pos=e+1; return num
  end
  parse_value = function()
    skip(); local c=s:sub(pos,pos)
    if c=='"' then return parse_string()
    elseif c=="{" then
      pos=pos+1; local obj={}; skip()
      if s:sub(pos,pos)=="}" then pos=pos+1; return obj end
      while true do
        skip(); local k=parse_string(); skip(); pos=pos+1
        obj[k]=parse_value(); skip()
        local d=s:sub(pos,pos); pos=pos+1
        if d=="}" then break elseif d=="," then else error("bad object d=[" .. tostring(d) .. "] @" .. pos) end
      end
      return obj
    elseif c=="[" then
      pos=pos+1; local arr={}; skip()
      if s:sub(pos,pos)=="]" then pos=pos+1; return arr end
      while true do
        arr[#arr+1]=parse_value(); skip()
        local d=s:sub(pos,pos); pos=pos+1
        if d=="]" then break elseif d=="," then else error("bad array") end
      end
      return arr
    elseif s:sub(pos,pos+3)=="null"  then pos=pos+4; return nil
    elseif s:sub(pos,pos+3)=="true"  then pos=pos+4; return true
    elseif s:sub(pos,pos+4)=="false" then pos=pos+5; return false
    else return parse_number() end
  end
  return parse_value()
end

-- ── stubs ────────────────────────────────────────────────────────────────────
local H = { pending = nil, stream = nil, done = nil, timeout = nil, asyncFails = false,
  notified = {}, errors = {}, logs = {}, noCreds = false, accountExpiry = nil }
local widget = { text = nil, color = nil, tooltip = nil }

local function make_noctalia(cfg)
  cfg = cfg or {}
  return {
    expandPath = function(p) return p:gsub("^~", os.getenv("HOME")) end,
    getConfig = function(k) return cfg[k] end,
    readFile = function(path)
      if H.noCreds then return nil end
      if path:match("current$") then return "a\n" end
      if path:match("credentials%.json$") then
        return '{"org_id":"wrk_A","access_token":"tok_a","expires_at":2111111111}'
      end
      local acct = path:match("accounts/([%w_%-]+)%.json$")
      if acct then
        local e = H.accountExpiry and H.accountExpiry[acct]
        if e == nil then return nil end
        return '{"org_id":"wrk_X","access_token":"t","expires_at":' .. e .. '}'
      end
      return nil
    end,
    json = { decode = function(s) local ok, v = pcall(json_decode, s); if ok then return v end return nil end },
    http = function(req, cb) H.pending = cb; H.lastReq = req; return true end,
    runAsync = function(cmd, cb, timeout)
      H.stream = cmd; H.done = cb; H.timeout = timeout
      if not H.asyncFails then return true end
      return false
    end,
    listDir = function() return { "a.json", "b.json" } end,
    fileExists = function() return true end,
    setUpdateInterval = function() end,
    notify = function(t, b) H.notified[#H.notified+1] = { t, b } end,
    notifyError = function(t, b) H.errors[#H.errors+1] = { t, b } end,
    formatTime = function(f) return os.date(f) end,
    log = function(...) H.logs[#H.logs+1] = table.concat({...}, " ") end,
  }
end

local function newWidget(cfg)
  H.pending, H.stream, H.done, H.timeout, H.asyncFails = nil, nil, nil, nil, false
  H.notified, H.errors, H.logs, H.noCreds, H.accountExpiry = {}, {}, {}, false, nil
  widget.text, widget.color, widget.tooltip = nil, nil, nil
  _G.noctalia = make_noctalia(cfg)
  _G.barWidget = {
    setText = function(t) widget.text = t end,
    setColor = function(c) widget.color = c end,
    setTooltip = function(rows) widget.tooltip = rows end,
  }
  local chunk = assert(loadfile(PLUGIN))
  chunk()
  return { update = _G.update, onClick = _G.onClick, onIpc = _G.onIpc, widget = widget }
end

local function respond(body, status, ok)
  assert(H.pending, "no pending http request")
  local cb = H.pending; H.pending = nil
  cb({ ok = (ok ~= false), status = status or 200, body = body })
end

local function tooltip_text(rows)
  local parts = {}
  for _, r in ipairs(rows or {}) do parts[#parts+1] = r.key .. "=" .. tostring(r.value) end
  return table.concat(parts, " | ")
end

-- ── assertions ───────────────────────────────────────────────────────────────
local checks, fails = 0, 0
local function check(name, cond)
  checks = checks + 1
  if cond then print("  ok: " .. name)
  else fails = fails + 1; print("  FAIL: " .. name) end
end

local function meters(five, week, month)
  return ('{"access":{"endsAt":"2026-11-01T00:00:00.000Z","meters":{'
    .. '"fiveHour":{"resetsAt":null,"limitMicroCents":"1200000000","usedMicroCents":"%d"},'
    .. '"week":{"resetsAt":"2026-10-05T00:00:00.000Z","limitMicroCents":"3000000000","usedMicroCents":"%d"},'
    .. '"month":{"limitMicroCents":"6000000000","usedMicroCents":"%d"}}}}'):format(five, week, month)
end

print("### 1: старт без данных -> setup")
local w = newWidget()
check("текст A ⚙", w.widget.text == "A ⚙")

print("### 2: успешный ответ -> проценты худшего метра")
respond(meters(120000000, 300000000, 1800000000)) -- 10% / 10% / 30%
check("текст A 30%", w.widget.text == "A 30%")
check("цвет success", w.widget.color == "success")
check("тултип содержит 5h", tooltip_text(w.widget.tooltip):find("5h=") ~= nil)

print("### 3: сеть отвалилась -> stale, цифры сохранены")
w.onIpc("refresh")
respond(nil, 0, false)
check("текст всё ещё A 30%", w.widget.text == "A 30%")
check("цвет muted", w.widget.color == "on_surface_variant")
check("тултип: строка связи", tooltip_text(w.widget.tooltip):find("связь=нет свежих данных") ~= nil)

print("### 4: восстановление связи -> снова ok")
w.onIpc("refresh")
respond(meters(600000000, 300000000, 1800000000)) -- 50% / 10% / 30%
check("текст A 50%", w.widget.text == "A 50%")
check("нет строки связи", tooltip_text(w.widget.tooltip):find("связь=") == nil)

print("### 5: 403 -> auth, показан ⚠ (цифры не показываем)")
w.onIpc("refresh")
respond("{}", 403, true)
check("текст A ⚠", w.widget.text == "A ⚠")

print("### 6: клик в режиме switch -> runAsync с 'use', метка без разметки")
local w6 = newWidget()
respond(meters(0, 0, 0))
w6.onClick()
check("runAsync вызван", H.stream ~= nil and H.stream:find("opencode%-go%-auth") ~= nil)
check("цель = b", H.stream ~= nil and H.stream:find("use 'b'") ~= nil)
check("таймаут задан", H.timeout == 30000)
check("метка B… (без <span>)", w6.widget.text == "B… 0%")
check("в баре нет тегов", w6.widget.text:find("[<>]") == nil)

print("### 6b: переключение завершилось -> метка активного аккаунта")
H.done({ exitCode = 0 })
check("после done запрос ушёл", H.pending ~= nil)
respond(meters(120000000, 0, 0))
check("текст A 10%", w6.widget.text == "A 10%")
check("без ошибок", #H.errors == 0)

print("### 6c: новый аккаунт без подписки (403) -> метка без разметки и не залипает")
local w6c = newWidget()
respond(meters(0, 0, 0))
w6c.onClick()
H.done({ exitCode = 0 })
respond("{}", 403, true)
check("метка A ⚠ (не B…)", w6c.widget.text == "A ⚠")
check("нет тегов", w6c.widget.text:find("[<>]") == nil)

print("### 6d: переключение упало -> notifyError, метка сброшена")
local w6d = newWidget()
respond(meters(0, 0, 0))
w6d.onClick()
H.done({ exitCode = 1, stderr = "no credentials for account 'b'\n" })
check("есть ошибка", #H.errors == 1)
check("в ошибке есть stderr", H.errors[1] ~= nil and H.errors[1][2]:find("no credentials") ~= nil)
check("метка сброшена", w6d.widget.text:find("…") == nil)
check("нет тегов", w6d.widget.text:find("[<>]") == nil)

print("### 6e: сторож снимает залипшее переключение через 30с")
local w6e = newWidget()
respond(meters(0, 0, 0))
w6e.onClick()
check("идёт переключение", w6e.widget.text:find("B…") ~= nil)
local realTime = os.time
os.time = function() return realTime() + 120 end
w6e.update()
os.time = realTime
check("метка вернулась к активному", w6e.widget.text:find("B…") == nil)
check("нет тегов", w6e.widget.text:find("[<>]") == nil)

print("### 7: display=all -> все метры в баре")
local w7 = newWidget({ display = "all" })
respond(meters(120000000, 300000000, 1800000000))
check("текст со всеми метрами", w7.widget.text == "A 5h 10% · week 10% · month 30%")

print("### 8: процент >100 обрезается")
local w8 = newWidget()
respond(meters(9000000000, 0, 0)) -- 750% -> 100
check("текст A 100%", w8.widget.text == "A 100%")

print("### 9: нет access.meters + _tag -> auth")
local w9 = newWidget()
respond('{"_tag":"Unauthorized"}')
check("текст A ⚠", w9.widget.text == "A ⚠")

print("### 10: ответ не JSON -> ! (нет данных для stale)")
local w10 = newWidget()
respond("not json at all")
check("текст A !", w10.widget.text == "A !")

print("### 11: нет credentials -> setup ⚙")
H.noCreds = true
local w11b = newWidget()
H.noCreds = false
check("текст с ⚙", w11b.widget.text:find("⚙") ~= nil)

print("### 12: ручное обновление через onIpc")
local w12 = newWidget()
respond(meters(0, 0, 0))
w12.onIpc("refresh")
check("после onIpc появился новый запрос", H.pending ~= nil)

print("### 13: протухший токен соседа -> не переключаемся на мёртвый аккаунт")
local w13 = newWidget()
respond(meters(0, 0, 0))
H.accountExpiry = { a = os.time() + 86400, b = os.time() - 86400 }
w13.onClick()
check("переключения нет", H.stream == nil)
check("это обновление данных", H.pending ~= nil)
check("нет ошибок", #H.errors == 0)

print("### 14: все токены протухли -> понятная ошибка, без переключения")
local w14 = newWidget()
respond(meters(0, 0, 0))
H.accountExpiry = { a = os.time() - 10, b = os.time() - 10 }
w14.onClick()
check("переключения нет", H.stream == nil)
check("есть ошибка", #H.errors == 1)
check("ошибка про токены", H.errors[1] ~= nil and H.errors[1][2]:find("протухли") ~= nil)

print()
print(("%d/%d checks passed"):format(checks - fails, checks))
os.exit(fails == 0 and 0 or 1)
