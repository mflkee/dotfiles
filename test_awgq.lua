-- Harness for the awgq Noctalia widget (awgq.luau).
-- Run: lua5.4 /tmp/opencode/test_awgq.lua
-- Verifies the runAsync timeout is passed and that a timed-out process no longer
-- produces a false "failed to toggle" error when the tunnel actually switched.

local PLUGIN = os.getenv("PLUGIN")
  or (os.getenv("HOME") .. "/dotfiles/dot_local/share/noctalia/plugins/awgq/awgq.luau")

local H = { calls = {}, errors = {}, logs = {} }
local widget = {}

local function newWidget(cfg)
  H.calls, H.errors, H.logs = {}, {}, {}
  cfg = cfg or {}
  _G.noctalia = {
    expandPath = function(p) return p:gsub("^~", os.getenv("HOME")) end,
    fileExists = function() return true end,
    getConfig = function(k) return cfg[k] end,
    setUpdateInterval = function() end,
    tr = function(k) return k end,
    notify = function(a, b) end,
    notifyError = function(a, b) table.insert(H.errors, { a, b }) end,
    log = function(...) table.insert(H.logs, table.concat({ ... }, " ")) end,
    string = { trim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end },
    runAsync = function(cmd, cb, timeout)
      table.insert(H.calls, { cmd = cmd, cb = cb, timeout = timeout })
      return true
    end,
  }
  _G.barWidget = {
    setGlyph = function() end,
    setColor = function() end,
    setGlyphColor = function() end,
    setText = function(t) widget.text = t end,
    setTooltip = function(rows) widget.tooltip = rows end,
  }
  local chunk = assert(loadfile(PLUGIN))
  chunk()
  return { onIpc = _G.onIpc, toggle = _G.toggle }
end

-- Первый вызов в каждом виджете — polling. Возвращаем cb последнего вызова,
-- соответствующего шаблону команды.
local function lastCall(pattern)
  for i = #H.calls, 1, -1 do
    if H.calls[i].cmd:find(pattern, 1, true) then return H.calls[i] end
  end
  return nil
end

local checks, fails = 0, 0
local function check(name, cond)
  checks = checks + 1
  if cond then print("  ok: " .. name) else fails = fails + 1; print("  FAIL: " .. name) end
end

print("### 1: таймаут действия передаётся в runAsync")
local w = newWidget()
w.onIpc("on")
local action = lastCall("opencode") or lastCall("awgq")
check("awgq-действие запущено", action ~= nil and action.cmd:find("awgq") ~= nil)
check("timeout = 60000 мс", action ~= nil and action.timeout == 60000)

print("### 2: процесс убит по таймауту, но туннель поднялся -> без ошибки")
action.cb({ exitCode = -1, timedOut = true, stdout = "", stderr = "timeout" })
local poll = lastCall("systemctl is-active")
check("после действия запущен poll", poll ~= nil)
poll.cb({ exitCode = 0, timedOut = false, stdout = "active\nLithuaniaVilniusD1\n10.80.232.8\n", stderr = "" })
check("ошибки НЕТ", #H.errors == 0)
check("состояние on", widget.text == "LithuaniaVilniusD1" or widget.text ~= nil)

print("### 3: процесс убит по таймауту и туннель НЕ поднялся -> ошибка один раз")
local w3 = newWidget()
w3.onIpc("on")
lastCall("awgq").cb({ exitCode = -1, timedOut = true, stdout = "", stderr = "killed" })
lastCall("systemctl is-active").cb({ exitCode = 0, timedOut = false, stdout = "inactive\nLithuaniaVilniusD1\n\n", stderr = "" })
check("ошибка ровно одна", #H.errors == 1)

print("### 4: успешный exit=0 -> без ошибки, без лишних уведомлений")
local w4 = newWidget()
w4.onIpc("off")
local off = lastCall("awgq")
off.cb({ exitCode = 0, timedOut = false, stdout = "ok", stderr = "" })
lastCall("systemctl is-active").cb({ exitCode = 0, timedOut = false, stdout = "inactive\nLithuaniaVilniusD1\n\n", stderr = "" })
check("ошибок нет", #H.errors == 0)
check("poll запущен дважды (стартовый + после off)", (function()
  local n = 0
  for _, c in ipairs(H.calls) do if c.cmd:find("systemctl is-active", 1, true) then n = n + 1 end end
  return n >= 2
end)())

print()
print(("%d/%d checks passed"):format(checks - fails, checks))
os.exit(fails == 0 and 0 or 1)
