-- dsync-capture: мгновенный захват dotfiles через dsync на сохранение.
--
-- Что делает: при :w любого файла, которым управляет chezmoi (живой файл
-- типа ~/.zshrc или исходник в ~/dotfiles), асинхронно запускает
-- `dsync capture <path>` — файл re-add-ится в репозиторий и пуш уходит
-- на hub, откуда флот получает его по SSH-pull.
--
-- Правки из других мест (bash, sed, скрипты) ловит периодический захват
-- внутри `dsync push` — этот хук лишь ускоряет путь nvim.
--
-- Отключить: set g:dsync_capture_enabled = v:false

local M = {}
local home = vim.fn.expand('~')
local dotfiles_src = home .. '/dotfiles'
local dsync_bin = home .. '/.local/bin/dsync'

local last_fired = {}
local DEBOUNCE_NS = 2_000_000_000 -- 2s на путь, чтобы не спамить при повторных :w

local function enabled()
  -- vimscript `let g:dsync_capture_enabled = v:false` приходит в Lua как false;
  -- 0 — тоже считаем выключенным.
  if vim.g.dsync_capture_enabled == false or vim.g.dsync_capture_enabled == 0 then
    return false
  end
  -- молча пропускаем, если dsync не установлен (например, на машине без него)
  return vim.fn.executable(dsync_bin) == 1
end

local function should_fire(path)
  if path:sub(1, #home) ~= home then
    return false
  end
  if vim.fn.filereadable(path) ~= 1 then
    return false
  end
  -- правки прямо в исходнике dotfiles
  if path:sub(1, #dotfiles_src) == dotfiles_src then
    return true
  end
  -- живой файл под управлением chezmoi? (пустой вывод = не managed)
  local out = vim.fn.system({ 'chezmoi', 'managed', path })
  return out ~= ''
end

local function fire(path)
  local now = (vim.loop and vim.loop.hrtime()) or vim.uv.hrtime()
  if last_fired[path] and now - last_fired[path] < DEBOUNCE_NS then
    return
  end
  last_fired[path] = now

  vim.fn.jobstart({ dsync_bin, 'capture', path }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify('dsync: captured ✓', vim.log.levels.INFO, { title = 'dsync' })
        else
          vim.notify('dsync capture failed (' .. code .. ')', vim.log.levels.WARN, { title = 'dsync' })
        end
      end)
    end,
  })
end

local group = vim.api.nvim_create_augroup('DsyncCapture', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  callback = function(ev)
    if not enabled() then
      return
    end
    if vim.bo[ev.buf].buftype ~= '' then
      return
    end
    local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ':p')
    if path == '' then
      return
    end
    if should_fire(path) then
      fire(path)
    end
  end,
})

return M
-- autoloaded automatically via custom/plugins folder scan
