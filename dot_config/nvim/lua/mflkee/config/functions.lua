--- Shared helpers used by `ftplugin/markdown.lua`, `ftplugin/quarto.lua` and the
--- global `<leader>o` mapping (see `init.lua`).
---
--- `<leader>o` opens whatever is under the cursor:
---   * markdown/quarto links: `[text](notes/note.md)`, `[[note]]`, `<https://…>`
---     and bare URLs — URLs open in the browser, notes/paths open as buffers;
---   * code: string literal paths (`"./example.rs"`, `include_str!("…")`),
---     `mod foo;` declarations and plain file names.
---
--- The browser defaults to `zen-browser`; override with
--- `let g:mflkee_browser = 'firefox'`.
local M = {}

--- Files that mark the top of a project. Used to resolve relative links that do
--- not exist next to the current buffer.
local project_markers = { '.git', '.obsidian', 'Cargo.toml', 'package.json', 'pyproject.toml', 'mkdocs.yml', 'quarto.yml', 'go.mod' }

--- Notes tried when a link points at a directory instead of a file.
local directory_notes = { 'README.md', 'index.md' }

---@param value string
---@return string
local function decode_uri_component(value)
  return (value:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end))
end

---@param heading string
---@return string
local function slugify_heading(heading)
  heading = heading:lower()
  heading = heading:gsub('`', '')
  heading = heading:gsub('[%p]', '')
  heading = heading:gsub('%s+', '-')
  return heading
end

---@param target string
---@return string|nil scheme
local function target_scheme(target)
  local scheme = target:match '^(%a[%w+%.%-]*):'
  -- Single letter schemes are treated as drive letters, not URL schemes.
  if scheme and #scheme > 1 then return scheme:lower() end
end

---@param target string
---@return boolean
local function is_external_url(target)
  local scheme = target_scheme(target)
  return scheme ~= nil and scheme ~= 'file'
end

---@param target string
---@return string path, string|nil anchor
local function split_anchor(target)
  local hash = target:find('#', 1, true)
  if hash then return target:sub(1, hash - 1), target:sub(hash + 1) end
  return target, nil
end

---@param raw string target as written inside the markup
---@return string|nil
local function clean_target(raw)
  raw = raw:gsub('^%s+', ''):gsub('%s+$', '')
  if raw == '' then return nil end
  -- [text](<path with spaces>)
  if raw:sub(1, 1) == '<' then return raw:match '^<(.-)>' end
  -- [text](path "optional title")
  return raw:match '^(%S+)'
end

--- Link, autolink or bare URL under the cursor.
---@return string|nil target, string|nil kind
local function link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local from = 1

  -- [text](target)
  while true do
    local start_pos, end_pos, raw = line:find('%[[^%]]*%]%((.-)%)', from)
    if not start_pos then break end
    if col >= start_pos and col <= end_pos then
      local target = clean_target(raw)
      if target then return decode_uri_component(target), 'link' end
    end
    from = end_pos + 1
  end

  -- [[note#anchor|alias]] (Obsidian style)
  while true do
    local start_pos, end_pos, raw = line:find('%[%[([^%]]+)%]%]', from)
    if not start_pos then break end
    if col >= start_pos and col <= end_pos then
      local target = raw:gsub('|.*$', '')
      if target ~= '' then return decode_uri_component(target), 'wikilink' end
    end
    from = end_pos + 1
  end

  -- <https://example.com> and <user@example.com>
  while true do
    local start_pos, end_pos, raw = line:find('<([^<>]+)>', from)
    if not start_pos then break end
    if col >= start_pos and col <= end_pos then
      raw = raw:gsub('%s+$', '')
      if raw:match '^[%w%.%+%-_]+@[%w%.%-]+$' then return 'mailto:' .. raw, 'url' end
      if target_scheme(raw) then return raw, 'url' end
    end
    from = end_pos + 1
  end

  -- bare https://example.com
  while true do
    local start_pos, end_pos, url = line:find('https?://[^%s<>"%[%]()]+', from)
    if not start_pos then break end
    if col >= start_pos and col <= end_pos then return url:gsub('[,%.:;]+$', ''), 'url' end
    from = end_pos + 1
  end
end

---@return string
local function buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then return vim.fn.getcwd() end
  return vim.fn.fnamemodify(name, ':p:h')
end

---@param name string
---@return string|nil
local function find_upward(name) return vim.fs.find(name, { upward = true, path = buffer_dir(), limit = 1 })[1] end

---@return string|nil
local function project_root()
  local marker = vim.fs.find(project_markers, { upward = true, path = buffer_dir(), limit = 1 })[1]
  return marker and vim.fs.dirname(marker) or nil
end

--- Resolve a path typed inside the buffer: as given (with `~` expanded),
--- relative to the current file, then relative to the project/crate root.
---@param raw string
---@param opts { extra_roots?: string[], extensions?: string[] }|nil
---@return string|nil
local function resolve_path(raw, opts)
  opts = opts or {}
  if raw == nil or raw == '' then return nil end

  if raw:sub(1, 1) == '~' then raw = vim.fn.expand(raw) end

  -- Absolute paths are taken as they are.
  if raw:sub(1, 1) == '/' then
    if vim.fn.filereadable(raw) == 1 or vim.fn.isdirectory(raw) == 1 then return vim.fn.fnamemodify(raw, ':p') end
    return nil
  end

  local roots = { buffer_dir() }
  vim.list_extend(roots, opts.extra_roots or {})

  local candidates = { raw }
  for _, ext in ipairs(opts.extensions or {}) do
    if raw:sub(-#ext) ~= ext then table.insert(candidates, raw .. ext) end
  end

  for _, root in ipairs(roots) do
    for _, candidate in ipairs(candidates) do
      local full = root .. '/' .. candidate
      if vim.fn.filereadable(full) == 1 or vim.fn.isdirectory(full) == 1 then return vim.fn.fnamemodify(full, ':p') end
    end
  end

  -- Last resort: relative to Neovim's current working directory.
  if vim.fn.filereadable(raw) == 1 or vim.fn.isdirectory(raw) == 1 then return vim.fn.fnamemodify(raw, ':p') end
end

--- Obsidian style `[[note]]` links: fall back to a search by file name.
---@param raw string
---@return string|nil
local function search_by_name(raw)
  if raw:find('/', 1, true) then return nil end

  local names = { raw }
  if not raw:match '%.[%w]+$' then table.insert(names, raw .. '.md') end

  local roots = {}
  local root = project_root()
  if root then table.insert(roots, root) end
  table.insert(roots, buffer_dir())

  for _, dir in ipairs(roots) do
    local found = vim.fs.find(names, { path = dir, type = 'file', limit = 1 })[1]
    if found then return found end
  end
end

---@param anchor string
---@return boolean
local function jump_to_markdown_anchor(anchor)
  local target = slugify_heading(anchor)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for index, line in ipairs(lines) do
    local heading = line:match '^#+%s+(.+)$'
    if heading and slugify_heading(heading) == target then
      vim.api.nvim_win_set_cursor(0, { index, 0 })
      vim.cmd 'normal! zz'
      return true
    end
  end

  return false
end

---@param path string
---@param anchor string|nil
local function open_path(path, anchor)
  if vim.fn.isdirectory(path) == 1 then
    local note
    for _, name in ipairs(directory_notes) do
      if vim.fn.filereadable(path .. '/' .. name) == 1 then
        note = path .. '/' .. name
        break
      end
    end
    if not note and vim.fn.filereadable(path .. '/' .. vim.fs.basename(path) .. '.md') == 1 then note = path .. '/' .. vim.fs.basename(path) .. '.md' end

    if not note then
      vim.cmd('lcd ' .. vim.fn.fnameescape(path))
      vim.notify('Directory: ' .. path, vim.log.levels.INFO)
      return
    end
    path = vim.fn.fnamemodify(note, ':p')
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(path))

  if anchor and anchor ~= '' and not jump_to_markdown_anchor(anchor) then vim.notify('Heading not found: #' .. anchor, vim.log.levels.WARN) end
end

---@param url string
local function open_url(url)
  local browser = vim.g.mflkee_browser
  if browser == nil or browser == '' then browser = 'zen-browser' end

  if vim.fn.executable(browser) == 1 then
    vim.fn.jobstart({ browser, '--new-tab', url }, { detach = true })
  else
    vim.ui.open(url)
  end
end

---@param target string
local function open_target(target)
  if target == nil or target == '' then return end

  if target_scheme(target) == 'file' then
    local path = decode_uri_component(target:gsub('^file://', ''))
    if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
      open_path(vim.fn.fnamemodify(path, ':p'))
    else
      vim.notify('File not found: ' .. path, vim.log.levels.WARN)
    end
    return
  end

  if is_external_url(target) then
    open_url(target)
    return
  end

  local path, anchor = split_anchor(target)
  path = decode_uri_component(path)

  local extra_roots = {}
  local root = project_root()
  if root then table.insert(extra_roots, root) end

  local resolved = resolve_path(path, { extra_roots = extra_roots, extensions = { '.md' } }) or search_by_name(path)
  if not resolved then
    vim.notify('File not found: ' .. target, vim.log.levels.WARN)
    return
  end

  open_path(resolved, anchor)
end

---@param value string
---@return boolean
local function looks_like_path(value)
  return value:find('/', 1, true) ~= nil
    or value:find('\\', 1, true) ~= nil
    or value:sub(1, 1) == '~'
    or value:match '^%.[%./]'
    or value:match '^[%w%-%_/]+%.[%w%-%_]+$'
end

--- String literal under the cursor, including raw strings (`r#"…"#`).
---@return string|nil
local function string_literal_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  for _, pattern in ipairs { 'r#"([^"]*)"#', 'r"([^"]*)"', '"([^"]*)"' } do
    local from = 1
    while true do
      local start_pos, end_pos, content = line:find(pattern, from)
      if not start_pos then break end
      if col >= start_pos and col <= end_pos then return content end
      from = end_pos + 1
    end
  end
end

--- Paths that may point to a file: the string under the cursor, macro and
--- module arguments when the cursor is not inside a literal, then the word
--- under the cursor.
---@return string[]
local function file_candidates_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local candidates, seen = {}, {}

  local function add(value)
    if value and value ~= '' and not seen[value] then
      seen[value] = true
      table.insert(candidates, value)
    end
  end

  local literal = string_literal_under_cursor()
  add(literal)

  if not literal then
    -- include_str!("data/table.csv"), include_bytes!(r#"…"#), include!(…)
    local macro = line:match 'include[_%w]*!%s*%(?%s*r?#?"(.*?)"#?%s*%)'
    add(macro)

    -- mod example; / pub mod example;
    local module = line:match '%f[%a]mod%s+([%w_]+)%s*;'
    if module then
      add(module .. '.rs')
      add(module .. '/mod.rs')
    end
  end

  local word = vim.fn.expand '<cfile>'
  if looks_like_path(word) then add((word:gsub('^["\']', ''):gsub('["\']$', ''))) end

  return candidates
end

--- Open the file the cursor points at: a path in a string literal, a macro or
--- module argument, or a file name.
function M.open_file_under_cursor()
  local extra_roots = {}
  local manifest = find_upward 'Cargo.toml'
  if manifest then
    local root = vim.fs.dirname(manifest)
    table.insert(extra_roots, root)
    table.insert(extra_roots, root .. '/src')
  end
  local root = project_root()
  if root then table.insert(extra_roots, root) end

  for _, candidate in ipairs(file_candidates_under_cursor()) do
    local resolved = resolve_path(candidate, { extra_roots = extra_roots })
    if resolved then
      open_path(resolved)
      return
    end
  end

  local word = vim.fn.expand '<cfile>'
  vim.notify('No file under cursor: ' .. (word ~= '' and word or '?'), vim.log.levels.WARN)
end

--- Open the link under the cursor (markdown link, wikilink, autolink or bare
--- URL); falls back to `open_file_under_cursor` when there is no link.
function M.open_target_under_cursor()
  local target = link_under_cursor()
  if target then
    open_target(target)
    return
  end

  M.open_file_under_cursor()
end

-- Names kept for the ftplugins and for backwards compatibility.
M.open_markdown_link_under_cursor = M.open_target_under_cursor
M.open_link_under_cursor = M.open_target_under_cursor

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
  vim.api.nvim_win_set_cursor(0, { current_line, cursor[2] })
end

function M.db_set_connection()
  local input = vim.fn.input 'DB (service name or full DSN): '
  local function build_dsn(s)
    if s and s:match '://' then return s end
    if s and s ~= '' then return 'postgresql://?service=' .. s end
    if vim.env.PGSERVICE and vim.env.PGSERVICE ~= '' then return 'postgresql://?service=' .. vim.env.PGSERVICE end
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
