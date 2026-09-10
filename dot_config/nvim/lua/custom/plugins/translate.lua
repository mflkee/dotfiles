local function show_float(title, text)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(text, '\n')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local vim_updates = vim.api.nvim_list_uis()
  local screen = vim_updates[1]
  local screen_w = screen and screen.width or 120
  local screen_h = screen and screen.height or 30
  local width = math.min(math.max(#text:gsub('\n.*', ''), 20) + 4, screen_w - 4)
  local height = math.min(#lines + 2, screen_h - 4)
  local win = vim.api.nvim_open_win(buf, true, {
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

local function translate_selection()
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local lines = vim.fn.getline(s[2], e[2])

  if #lines == 0 then
    return
  end

  lines[#lines] = string.sub(lines[#lines], 1, e[3])
  lines[1] = string.sub(lines[1], s[3])

  local text = table.concat(lines, '\n')
  if text == '' then
    return
  end

  local target = text:match '[а-яА-ЯёЁ]' and 'en' or 'ru'
  local ok, result = pcall(vim.fn.system, { 'trans', '-b', ':' .. target, text })
  if not ok or vim.v.shell_error ~= 0 then
    show_float('Translate — ошибка', 'translate-shell не найден или ошибка вызова.\nУбедись, что trans установлен (pacman -S translate-shell).')
    return
  end

  result = result:gsub('%s+$', '')
  show_float('→ ' .. target:upper(), result)
end

vim.keymap.set('v', '<leader>t', translate_selection, { desc = 'Translate ru<->en (selection)' })