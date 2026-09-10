-- ru<->en translation for visual selection using translate-shell (`trans`)
-- Single persistent window (updates in place, no stacking) + stale-result guard.
-- Selection via yank to register z ("zy) — nvim 0.12 leaves '< '>' marks ZERO during
-- active visual mode, so getpos-based approaches silently fail.
local LOG = vim.fn.stdpath 'cache' .. '/translate.log'

local function log(msg)
  local f = io.open(LOG, 'a')
  if f then
    f:write(os.date('%F %T') .. ' ' .. msg .. '\n')
    f:close()
  end
end

local win = nil

local function ensure_win(title, text)
  local lines = vim.split(text, '\n')
  local screen = vim.api.nvim_list_uis()[1]
  local screen_w = screen and screen.width or 120
  local screen_h = screen and screen.height or 30
  local width = math.min(math.max(#text:gsub('\n.*', ''), 20) + 4, screen_w - 4)
  local height = math.min(#lines + 2, screen_h - 4)

  if win and vim.api.nvim_win_is_valid(win) then
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_config(win, { width = width, height = height, title = title })
  else
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    win = vim.api.nvim_open_win(buf, false, {
      relative = 'editor',
      row = math.floor((screen_h - height) / 2),
      col = math.floor((screen_w - width) / 2),
      width = width,
      height = height,
      border = 'rounded',
      title = title,
      title_pos = 'center',
      style = 'minimal',
    })
    vim.wo[win].wrap = false
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, desc = 'Close' })
    vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf, desc = 'Close' })
    vim.keymap.set('n', 'y', function()
      vim.fn.setreg('+', text)
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, desc = 'Copy to clipboard' })
  end
end

local gen = 0

local M = {}
function M.run()
  local text = vim.fn.getreg('z')
  log('DBG invoke mode=' .. vim.fn.mode() .. ' reg_z=' .. (text == '' and '<empty>' or text:gsub('\n', '\\n')))

  if text == '' then
    log('DBG early-return: empty register z')
    return
  end

  gen = gen + 1
  local my = gen
  local target = text:match '[а-яА-ЯёЁ]' and 'en' or 'ru'
  log('req#' .. my .. '[' .. target .. ']: ' .. text:gsub('\n', '\\n'))

  ensure_win('→ ' .. target:upper() .. ' (перевожу…)', text)

  vim.system({ 'trans', '-b', ':' .. target, text }, function(finish)
    vim.schedule(function()
      if my ~= gen then
        log('req#' .. my .. ' STALE (gen=' .. gen .. ') ignored')
        return
      end
      local result = finish.stdout and finish.stdout:gsub('%s+$', '') or ''
      if finish.code ~= 0 or result == '' then
        log('req#' .. my .. ' ERROR code=' .. finish.code .. ' stderr=' .. (finish.stderr or ''):gsub('\n', '\\n'))
        ensure_win('Translate — ошибка', 'translate-shell ошибка (code ' .. finish.code .. ').\nПроверь сеть и trans (pacman -S translate-shell).')
        return
      end
      log('req#' .. my .. ' OK: ' .. result:gsub('\n', '\\n'))
      ensure_win('→ ' .. target:upper(), result)
    end)
  end)
end

vim.keymap.set('v', '<leader>t', [["zy<Cmd>lua require('custom.plugins.translate').run()<CR>]], { desc = 'Translate ru<->en (window)' })
vim.keymap.set('v', '<leader>T', [["zy<Cmd>lua require('custom.plugins.translate').run()<CR>]], { desc = 'Translate ru<->en (reverse)' })

log('translate module loaded (v9, register-yank)')

return M