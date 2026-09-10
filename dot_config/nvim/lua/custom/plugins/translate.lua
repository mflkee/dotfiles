local LOG = vim.fn.stdpath 'cache' .. '/translate.log'

local function log(msg)
  io.open(LOG, 'a'):write(os.date('%F %T') .. ' ' .. msg .. '\n')
end

local function show_float(title, text)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(text, '\n')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local screen = vim.api.nvim_list_uis()[1]
  local screen_w = screen and screen.width or 120
  local screen_h = screen and screen.height or 30
  local width = math.min(math.max(#text:gsub('\n.*', ''), 20) + 4, screen_w - 4)
  local height = math.min(#lines + 2, screen_h - 4)
  local win, err = vim.api.nvim_open_win(buf, true, {
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
  if not win then
    log('nvim_open_win failed: ' .. tostring(err))
    local lines_str = table.concat(lines, '\n')
    vim.notify(lines_str, vim.log.levels.INFO, { title = 'Translate' })
    return
  end
  vim.wo[win].wrap = false
  vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, desc = 'Close' })
  vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf, desc = 'Close' })
  vim.keymap.set('n', 'y', function()
    vim.fn.setreg('+', text)
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, desc = 'Copy to clipboard' })
end

local function translate_selection()
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local lines = vim.fn.getline(s[2], e[2])

  if #lines == 0 then
    log('no lines')
    return
  end

  lines[#lines] = string.sub(lines[#lines], 1, e[3])
  lines[1] = string.sub(lines[1], s[3])

  local text = table.concat(lines, '\n')
  if text == '' then
    log('empty selection')
    return
  end

  local target = text:match '[а-яА-ЯёЁ]' and 'en' or 'ru'
  log('requested[' .. target .. ']: ' .. text:gsub('\n', '\\n'))
  show_float('→ ' .. target:upper() .. ' (перевожу…)', text)

  vim.system({ 'trans', '-b', ':' .. target, text }, function(finish)
    local result = finish.stdout and finish.stdout:gsub('%s+$', '') or ''
    if finish.code ~= 0 then
      log('trans failed code=' .. finish.code .. ' stderr=' .. (finish.stderr or '') .. ' stdout=' .. (finish.stdout or ''))
      show_float('Translate — ошибка', 'translate-shell ошибка (code ' .. finish.code .. ').\n' .. (finish.stderr or 'Проверь сеть и trans (pacman -S translate-shell).'))
      return
    end
    log('ok: ' .. result:gsub('\n', '\\n'))
    show_float('→ ' .. target:upper(), result)
  end)
end

vim.keymap.set('v', '<leader>t', translate_selection, { desc = 'Translate ru<->en (selection)' })