local function translate_selection()
  -- сохраняем позиции начала/конца визуального выделения
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local lines = vim.fn.getline(s[2], e[2])

  if #lines == 0 then
    return
  end

  -- обрезаем до точных границ выделения (важно для character-wise visual)
  lines[#lines] = string.sub(lines[#lines], 1, e[3])
  lines[1] = string.sub(lines[1], s[3])

  local text = table.concat(lines, '\n')
  if text == '' then
    return
  end

  local target = text:match '[а-яА-ЯёЁ]' and 'en' or 'ru'

  local ok, result = pcall(vim.fn.system, { 'trans', '-b', ':' .. target, text })
  if not ok or vim.v.shell_error ~= 0 then
    vim.notify('translate-shell не найден или ошибка вызова', vim.log.levels.ERROR, { title = 'Translate' })
    return
  end

  result = result:gsub('%s+$', '')
  vim.notify(result, vim.log.levels.INFO, { title = '→ ' .. target })
end

vim.keymap.set('v', '<leader>t', translate_selection, { desc = 'Translate ru<->en (selection)' })
