local M = {}

local function decode_uri_component(value)
  return (value:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function slugify_heading(value)
  value = value:lower()
  value = value:gsub('`', '')
  value = value:gsub('[%p]', '')
  value = value:gsub('%s+', '-')
  return value
end

local function find_markdown_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local start = 1

  while true do
    local match_start, match_end, _, target = line:find('%[([^%]]-)%]%(([^%)]+)%)', start)
    if not match_start then
      return nil
    end

    if col >= match_start and col <= match_end then
      return target
    end

    start = match_end + 1
  end
end

local function resolve_markdown_target(target)
  local path, anchor = target:match '^(.-)#(.+)$'

  if not path then
    if target:sub(1, 1) == '#' then
      path = ''
      anchor = target:sub(2)
    else
      path = target
    end
  end

  path = decode_uri_component(path)

  local current_file = vim.api.nvim_buf_get_name(0)
  if path == '' then
    return current_file, anchor
  end

  if path:match '^/' then
    return path, anchor
  end

  local base_dir = vim.fn.fnamemodify(current_file, ':p:h')
  local resolved = vim.fn.fnamemodify(base_dir .. '/' .. path, ':p')
  return resolved, anchor
end

local function jump_to_markdown_anchor(anchor)
  local target = slugify_heading(anchor)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for index, line in ipairs(lines) do
    local heading = line:match '^#+%s+(.+)$'
    if heading and slugify_heading(heading) == target then
      vim.api.nvim_win_set_cursor(0, { index, 0 })
      return true
    end
  end

  return false
end

function M.open_file_under_cursor()
  local filepath = vim.fn.expand '<cfile>'
  if vim.fn.filereadable(filepath) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
  else
    vim.notify('File not found: ' .. filepath, vim.log.levels.WARN)
  end
end

function M.open_markdown_link_under_cursor()
  local target = find_markdown_link_under_cursor()
  if not target then
    return M.open_file_under_cursor()
  end

  local filepath, anchor = resolve_markdown_target(target)
  if vim.fn.filereadable(filepath) ~= 1 then
    vim.notify('File not found: ' .. filepath, vim.log.levels.WARN)
    return
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

  if anchor and anchor ~= '' and not jump_to_markdown_anchor(anchor) then
    vim.notify('Heading not found: ' .. anchor, vim.log.levels.WARN)
  end
end

function M.move_line(direction)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]
  local total_lines = vim.api.nvim_buf_line_count(0)

  local target_line
  if direction == 'up' and current_line > 1 then
    target_line = current_line - 1
  elseif direction == 'down' and current_line < total_lines then
    target_line = current_line + 1
  else
    return
  end

  local current_content = vim.api.nvim_get_current_line()
  local target_content = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)[1]

  vim.api.nvim_buf_set_lines(0, target_line - 1, target_line, false, { current_content })
  vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, { target_content })
  vim.api.nvim_win_set_cursor(0, { target_line, cursor[2] })
end

function M.db_set_connection()
  local input = vim.fn.input 'DB (service name or full DSN): '
  local function build_dsn(s)
    if s and s:match '://' then
      return s
    end
    if s and s ~= '' then
      return 'postgresql://?service=' .. s
    end
    if vim.env.PGSERVICE and vim.env.PGSERVICE ~= '' then
      return 'postgresql://?service=' .. vim.env.PGSERVICE
    end
    return nil
  end
  local dsn = build_dsn(input)
  if not dsn then
    vim.notify('DB: укажите сервис или DSN', vim.log.levels.WARN)
    return
  end
  vim.b.db = dsn
  vim.bo.filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'sql'
  vim.bo.omnifunc = 'vim_dadbod_completion#omni'
  vim.notify('DB: подключение для буфера установлено', vim.log.levels.INFO)
end

function M.db_new_query()
  vim.cmd 'enew'
  vim.bo.filetype = 'sql'
  vim.bo.omnifunc = 'vim_dadbod_completion#omni'
  local default = vim.env.PGSERVICE or ''
  local svc = vim.fn.input('DB service (пусто = PGSERVICE): ', default)
  if svc ~= '' or (vim.env.PGSERVICE and vim.env.PGSERVICE ~= '') then
    local name = (svc ~= '' and svc) or vim.env.PGSERVICE
    vim.b.db = 'postgresql://?service=' .. name
  end
  vim.notify('DB: открыт новый SQL буфер', vim.log.levels.INFO)
end

return M
