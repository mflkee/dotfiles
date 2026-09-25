-- PostgreSQL workflow для курса Rust + PostgreSQL.
--
-- Connections:
--   course     — основной стенд PostgreSQL 18, 127.0.0.1:15432/course
--   course_m06 — отдельная база модулей 06–13, 127.0.0.1:15432/course_m06
--   timescale  — TimescaleDB профиля timescale, 127.0.0.1:15433/course
--   capstone   — БД итогового проекта, 127.0.0.1:15442/capstone
--
-- Основные команды:
--   :SqlUse [name]       — выбрать подключение для текущего SQL-буфера
--   :SqlCycle            — переключить подключение по кругу
--   :Pgsql [name]        — открыть pgcli (или psql, если pgcli не установлен)
--   :SQLApply            — применить текущий сохранённый SQL-файл
--   :SQLCheck [asserts]  — проверить student.sql через infra/check-sql.sh
--   :PGCourseUp [...]    — поднять выбранные сервисы Compose
--   :PGCourseStatus      — показать состояние стенда
--
-- SQL-файлы получают buffer-local b:db автоматически по пути и первым
-- строкам комментария. При необходимости подключение всегда можно сменить
-- вручную через :SqlUse.

local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add { gh 'tpope/vim-dadbod' }
vim.pack.add { gh 'kristijanhusak/vim-dadbod-ui' }

local connections = {
  {
    name = 'course',
    url = 'postgres://course:course@127.0.0.1:15432/course?sslmode=disable',
    service = 'postgres',
    database = 'course',
    port = 15432,
  },
  {
    name = 'course_m06',
    url = 'postgres://course:course@127.0.0.1:15432/course_m06?sslmode=disable',
    service = 'postgres',
    database = 'course_m06',
    port = 15432,
  },
  {
    name = 'timescale',
    url = 'postgres://course:course@127.0.0.1:15433/course?sslmode=disable',
    service = 'timescale',
    database = 'course',
    port = 15433,
  },
  {
    name = 'capstone',
    url = 'postgres://course:course@127.0.0.1:15442/capstone?sslmode=disable',
    service = 'capstone',
    database = 'capstone',
    port = 15442,
  },
}

local connections_by_name = {}
for _, connection in ipairs(connections) do
  connections_by_name[connection.name] = connection
end

-- Dadbod и Dadbod UI используют один список подключений. URL из b:db имеет
-- приоритет над g:db в конкретном SQL-буфере.
vim.g.dbs = connections
vim.g.db = connections[1].url
vim.g.db_ui_use_nerd_fonts = true

M.connections = connections

local function normalize_path(path)
  if path == nil or path == '' then path = vim.fn.getcwd() end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
end

local function buffer_connection_name(bufnr)
  local ok, connection = pcall(vim.api.nvim_buf_get_var, bufnr, 'db_connection')
  if ok and connections_by_name[connection] then return connection end

  local has_url, url = pcall(vim.api.nvim_buf_get_var, bufnr, 'db')
  if has_url then
    for _, item in ipairs(connections) do
      if item.url == url then return item.name end
    end
  end

  return connections[1].name
end

local function current_connection() return connections_by_name[buffer_connection_name(0)] end

local function set_connection(name, bufnr)
  local connection = connections_by_name[(name or ''):lower()]
  if not connection then
    local names = vim.tbl_map(function(item) return item.name end, connections)
    error('Unknown connection "' .. tostring(name) .. '"; choose one of: ' .. table.concat(names, ', '), 0)
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_var(bufnr, 'db', connection.url)
  vim.api.nvim_buf_set_var(bufnr, 'db_connection', connection.name)
  return connection
end

local function choose_connection()
  local current = current_connection()
  local labels = vim.tbl_map(
    function(item) return ('%s — 127.0.0.1:%d/%s%s'):format(item.name, item.port, item.database, item.name == current.name and ' [current]' or '') end,
    connections
  )

  local choice = vim.fn.inputlist('PostgreSQL connection:', labels)
  if choice == 0 then return nil end
  return connections[choice]
end

-- Ищем корень курса, а не зашиваем домашний путь в dotfiles. Файл курса может
-- находиться в course/, infra/ или любом вложенном каталоге.
local function course_root()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  local start = buffer_name ~= '' and vim.fs.dirname(buffer_name) or vim.fn.getcwd()
  local dir = normalize_path(start)

  while dir and dir ~= '' do
    local compose = vim.fs.joinpath(dir, 'infra', 'docker-compose.yml')
    local readme = vim.fs.joinpath(dir, 'course', 'README.md')
    if vim.uv.fs_stat(compose) and vim.uv.fs_stat(readme) then return dir end
    if dir == '/' then break end
    dir = vim.fs.dirname(dir)
  end

  error('Course root not found: open a file below ~/projects/study/postgresql', 0)
end

-- Автовыбор базы нужен только при первом открытии файла (FileType). После
-- ручного :SqlUse он не перезаписывается до следующего открытия буфера.
local function guess_connection(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lower_path = path:lower()
  local header = {}

  if path ~= '' and vim.uv.fs_stat(path) then
    local ok, lines = pcall(vim.fn.readfile, path, '', 20)
    if ok then header = table.concat(lines, '\n'):lower() end
  end

  for _, line in ipairs(vim.split(header, '\n', { plain = true })) do
    local explicit = line:match '^%s*%-%-%s*db%s*:%s*([%w_%-]+)'
    if explicit and connections_by_name[explicit] then return connections_by_name[explicit] end
  end

  if
    lower_path:find '/14%-capstone%-historian/'
    or header:find('15442', 1, true)
    or header:find('database: capstone', 1, true)
    or header:find('база: capstone', 1, true)
  then
    return connections_by_name.capstone
  end

  if
    lower_path:find '/ex02_timescale/'
    or lower_path:match '/04%-timescale%.sql$'
    or header:find('15433', 1, true)
    or header:find('profile timescale', 1, true)
  then
    return connections_by_name.timescale
  end

  if header:find('course_m06', 1, true) then return connections_by_name.course_m06 end

  local m06_modules = {
    '/06%-sqlx%-in%-depth/',
    '/07%-performance/',
    '/08%-timeseries%-partitioning/',
    '/09%-plpgsql%-triggers%-notify/',
    '/10%-app%-patterns/',
    '/11%-web%-api%-axum/',
    '/12%-testing/',
    '/13%-ops%-reliability/',
  }
  for _, pattern in ipairs(m06_modules) do
    if lower_path:find(pattern) then return connections_by_name.course_m06 end
  end

  return connections[1]
end

local sql_group = vim.api.nvim_create_augroup('course-postgresql', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = sql_group,
  pattern = 'sql',
  callback = function(event)
    local has_connection = pcall(vim.api.nvim_buf_get_var, event.buf, 'db')
    if not has_connection then set_connection(guess_connection(event.buf).name, event.buf) end
  end,
})

local function run_in_terminal(label, command, options)
  options = options or {}

  vim.cmd 'botright 12split'
  local args = vim.deepcopy(command)

  local job = vim.fn.termopen(args, {
    cwd = options.cwd,
    on_exit = function(_, exit_code)
      vim.schedule(
        function() vim.notify(('%s exited with code %d'):format(label, exit_code), exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR) end
      )
    end,
  })

  if job <= 0 then
    vim.notify(('Failed to start: %s'):format(label), vim.log.levels.ERROR)
    return
  end

  vim.cmd.startinsert()
end

local compose_profiles = { '--profile', 'tools', '--profile', 'obs', '--profile', 'timescale' }
local compose_services = {
  'postgres',
  'pgadmin',
  'timescale',
  'prometheus',
  'postgres_exporter',
  'grafana',
}

local function compose_command(root, tail)
  local command = { 'docker', 'compose' }
  vim.list_extend(command, compose_profiles)
  vim.list_extend(command, tail)
  return command, root
end

local function open_repl(name)
  if name and name ~= '' then set_connection(name) end

  local connection = current_connection()
  local client = vim.fn.exepath 'pgcli' ~= '' and 'pgcli' or 'psql'
  if client == 'psql' then vim.notify('pgcli is not installed; using psql. Install with: sudo pacman -S pgcli', vim.log.levels.WARN) end

  local ok, toggleterm = pcall(require, 'toggleterm')
  if ok then
    local Terminal = toggleterm.terminal.Terminal
    local key = client .. ':' .. connection.name
    M.repl_terminals = M.repl_terminals or {}
    local terminal = M.repl_terminals[key]

    if not terminal then
      terminal = Terminal:new {
        cmd = ('%s %s'):format(client, vim.fn.shellescape(connection.url)),
        direction = 'float',
        close_on_exit = false,
      }
      M.repl_terminals[key] = terminal
    end

    if terminal:is_open() then
      terminal:close()
    else
      terminal:toggle()
      vim.cmd.startinsert()
    end
    return
  end

  vim.cmd 'botright 12split'
  local job = vim.fn.termopen { client, connection.url }
  if job > 0 then
    vim.cmd.startinsert()
  else
    vim.notify(('Failed to start %s'):format(client), vim.log.levels.ERROR)
  end
end

local function current_sql_file(require_saved)
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' or path:match '^term://' then error('Open a SQL file first', 0) end
  if require_saved and vim.bo.modified then error('Save the buffer before running this command', 0) end
  if vim.uv.fs_stat(path) then return normalize_path(path) end
  error('SQL file is not saved yet', 0)
end

local function apply_current_sql()
  local file = current_sql_file(true)
  local connection = current_connection()
  run_in_terminal('SQLApply (' .. connection.name .. ')', { 'psql', connection.url, '-v', 'ON_ERROR_STOP=1', '-f', file }, { cwd = course_root() .. '/infra' })
end

local function check_current_sql(args)
  local student = current_sql_file(true)
  local asserts = args.args

  if asserts == '' then
    asserts = vim.fs.joinpath(vim.fs.dirname(student), 'asserts.sql')
  elseif not vim.startswith(asserts, '/') then
    asserts = normalize_path(asserts)
  end

  if not vim.uv.fs_stat(asserts) then error('Asserts file not found: ' .. asserts, 0) end

  local connection = current_connection()
  if connection.name == 'capstone' then error('SQLCheck is intended for course exercises; use capstone_integration tests for module 14', 0) end

  local root = course_root()
  run_in_terminal(('SQLCheck (%s/%s)'):format(connection.service, connection.database), {
    vim.fs.joinpath(root, 'infra', 'check-sql.sh'),
    student,
    asserts,
    connection.service,
    connection.database,
  }, { cwd = root })
end

vim.keymap.set({ 'n', 'v' }, '<leader>qr', ':<C-U>DB<CR>', { desc = '[R]un SQL query (Dadbod)' })
vim.keymap.set('n', '<leader>qd', '<cmd>DBUI<CR>', { desc = '[D]ata[b]ase UI' })
vim.keymap.set('n', '<leader>qp', function() open_repl() end, { desc = 'Open PostgreSQL REPL' })
vim.keymap.set('n', '<leader>qu', function()
  local connection = choose_connection()
  if connection then
    set_connection(connection.name)
    vim.notify('SQL connection: ' .. connection.name, vim.log.levels.INFO)
  end
end, { desc = 'Select SQL connection for buffer' })
vim.keymap.set('n', '<leader>qC', function()
  local current = buffer_connection_name(0)
  local index = 1
  for i, connection in ipairs(connections) do
    if connection.name == current then
      index = i
      break
    end
  end
  local connection = connections[(index % #connections) + 1]
  set_connection(connection.name)
  vim.notify('SQL connection: ' .. connection.name, vim.log.levels.INFO)
end, { desc = 'Cycle SQL connection' })
vim.keymap.set('n', '<leader>qa', apply_current_sql, { desc = '[A]pply SQL file' })
vim.keymap.set('n', '<leader>qx', function() check_current_sql { args = '' } end, { desc = 'Check SQL exercise' })

vim.api.nvim_create_user_command('SqlUse', function(command)
  local name = command.args
  local connection
  if name == '' then
    connection = choose_connection()
    if not connection then return end
  else
    connection = connections_by_name[name:lower()]
    if not connection then error('Unknown connection: ' .. name, 0) end
  end

  set_connection(connection.name)
  vim.notify('SQL connection for this buffer: ' .. connection.name, vim.log.levels.INFO)
end, {
  nargs = '?',
  complete = function()
    return vim.tbl_map(function(item) return item.name end, connections)
  end,
  desc = 'Select PostgreSQL connection for current buffer',
})

vim.api.nvim_create_user_command('SqlCycle', function()
  local current = buffer_connection_name(0)
  local next_name
  for index, connection in ipairs(connections) do
    if connection.name == current then
      next_name = connections[(index % #connections) + 1].name
      break
    end
  end
  set_connection(next_name or connections[1].name)
  vim.notify('SQL connection for this buffer: ' .. buffer_connection_name(0), vim.log.levels.INFO)
end, { desc = 'Cycle PostgreSQL connection' })

vim.api.nvim_create_user_command('Pgsql', function(command) open_repl(command.args) end, {
  nargs = '?',
  complete = function()
    return vim.tbl_map(function(item) return item.name end, connections)
  end,
  desc = 'Open pgcli/psql for a course connection',
})

vim.api.nvim_create_user_command('SQLApply', apply_current_sql, { desc = 'Apply current SQL file' })
vim.api.nvim_create_user_command('SQLCheck', check_current_sql, {
  nargs = '?',
  desc = 'Check current SQL exercise (defaults to adjacent asserts.sql)',
})

vim.api.nvim_create_user_command('PGCourseUp', function(command)
  local root = course_root()
  local services = vim.trim(command.args) ~= '' and vim.split(vim.trim(command.args), '%s+') or { 'postgres', 'pgadmin' }
  local tail = { 'up', '-d' }
  vim.list_extend(tail, services)
  local command_line, cwd = compose_command(root, tail)
  run_in_terminal('PGCourseUp', command_line, { cwd = cwd })
end, {
  nargs = '*',
  complete = function() return compose_services end,
  desc = 'Start course Compose services (default: postgres pgadmin)',
})

vim.api.nvim_create_user_command('PGCourseStop', function(command)
  if vim.trim(command.args) == '' then error('Specify at least one service (for example: :PGCourseStop postgres)', 0) end
  local root = course_root()
  local tail = { 'stop' }
  vim.list_extend(tail, vim.split(vim.trim(command.args), '%s+'))
  local command_line, cwd = compose_command(root, tail)
  run_in_terminal('PGCourseStop', command_line, { cwd = cwd })
end, {
  nargs = '+',
  complete = function() return compose_services end,
  desc = 'Stop selected course Compose services',
})

vim.api.nvim_create_user_command('PGCourseStatus', function()
  local root = course_root()
  local command_line, cwd = compose_command(root, { 'ps' })
  run_in_terminal('PGCourseStatus', command_line, { cwd = cwd })
end, { desc = 'Show course Compose service status' })

return M
