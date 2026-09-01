local M = {}

local cyrillic = vim.regex [=[\v[А-Яа-яЁё]]=]
local preview_max_height = 10
local endpoint = 'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=%s&tl=%s'

local function lang_pair(text)
  if cyrillic:match_str(text) then
    return 'ru', 'en'
  end
  return 'en', 'ru'
end

local function extract_translation(data)
  if type(data) ~= 'table' then
    return nil
  end
  local out = {}
  for _, seg in ipairs(data) do
    if type(seg) == 'string' then
      out[#out + 1] = seg
    elseif type(seg) == 'table' and type(seg[1]) == 'string' then
      out[#out + 1] = seg[1]
    end
  end
  if #out == 0 then
    return nil
  end
  return table.concat(out, '')
end

local function echo_result(query, translation)
  local lines = {}
  if query and query ~= '' then
    lines[1] = '⟦ ' .. query .. ' ⟧'
  end
  lines[#lines + 1] = translation
  vim.api.nvim_echo({ { table.concat(lines, '\n'), 'String' } }, false, {})
end

local function show_window(query, translation)
  local lines = {}
  if query and query ~= '' then
    vim.list_extend(lines, { '⟦ ' .. query .. ' ⟧', '' })
  end
  vim.list_extend(lines, vim.split(translation, '\n', { plain = true }))
  local height = math.min(preview_max_height, #lines)
  local width = math.min(60, math.max(20, vim.api.nvim_win_get_width(0) - 4))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'translator')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' translate ',
    title_pos = 'center',
  })
  local hidemap = '<cmd>lua vim.api.nvim_win_close(0, true)<CR>'
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', hidemap, { nowait = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', hidemap, { nowait = true })
  return win
end

local function translate(text, display_mode)
  if not text or vim.trim(text) == '' then
    vim.notify('Nothing to translate', vim.log.levels.WARN)
    return
  end

  local source_lang, target_lang = lang_pair(text)
  local url = endpoint:format(source_lang, target_lang)

  vim.system({ 'curl', '-sS', '-m', '10', '-G', url, '--data-urlencode', 'q=' .. text }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.notify('Translate request failed: ' .. (result.stderr or result.code), vim.log.levels.ERROR)
      return
    end
    local ok, data = pcall(vim.json.decode, result.stdout)
    if not ok then
      vim.notify('Invalid translate response', vim.log.levels.ERROR)
      return
    end
    local translation = extract_translation(data)
    if not translation or translation == '' then
      vim.notify('Nothing to translate', vim.log.levels.WARN)
      return
    end
    vim.schedule(function()
      if display_mode == 'window' then
        show_window(text, translation)
      else
        echo_result(text, translation)
      end
    end)
  end)
end

local function get_selection()
  local mode = vim.fn.mode()
  if mode == '\22' then
    vim.notify('Blockwise translation is not supported', vim.log.levels.WARN)
    return nil
  end

  local start_pos = vim.fn.getpos 'v'
  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_row, start_col = start_pos[2], start_pos[3]
  local end_row, end_col = cursor[1], cursor[2] + 1

  if start_row == 0 or end_row == 0 then
    return nil
  end
  if mode == 'V' then
    start_col, end_col = 1, #vim.fn.getline(end_row)
  end
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.fn.getline(start_row, end_row)
  if vim.tbl_isempty(lines) then
    return nil
  end
  if start_row == end_row then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end
  return table.concat(lines, '\n')
end

function M.visual(display_mode)
  translate(get_selection(), display_mode)
end

function M.word(display_mode)
  translate(vim.fn.expand '<cword>', display_mode)
end

return M
