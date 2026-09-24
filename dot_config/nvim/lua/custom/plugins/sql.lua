-- sql.lua — PostgreSQL workflow для обучения и написания SQL-скриптов.
--
-- Что даёт:
--   * vim-dadbod + vim-dadbod-ui — выполнять запросы из буфера и смотреть
--     результат в таблице, браузер БД (таблицы, схемы, данные)
--   * pgcli — интерактивный REPL с автокомплитом в плавающем терминале
--   * sqls LSP (ставится через mason) — подсказки по таблицам/колонкам,
--     конфиг подключения: ~/.config/sqls/config.yml
--   * pg_format (пакет pgformatter) — автоформатирование .sql при сохранении
--     (настроено в init.lua, секция conform)
--
-- Keymaps:
--   <leader>qr  — выполнить выделенное или текущий запрос (dadbod)
--   <leader>qd  — открыть браузер БД (dadbod-ui)
--   <leader>qp  — открыть pgcli в плавающем терминале (или команда :Pgsql)
--
-- По умолчанию коннектимся к локальному кластеру PostgreSQL
-- (user == $USER, база == $PGDATABASE или $USER). Переопределить на лету:
--   :DB postgres://user:pass@host:5432/db
-- или переменными окружения (PGHOST, PGDATABASE, ...).

local M = {}

local function gh(repo)
  return 'https://github.com/' .. repo
end

-- --- Соединение по умолчанию ------------------------------------------
local function default_url()
  local user = os.getenv 'USER'
  local db = os.getenv 'PGDATABASE' or user
  return string.format('postgres://%s@127.0.0.1:5432/%s?sslmode=disable', user, db)
end

-- --- dadbod + dadbod-ui через нативный vim.pack (как остальные плагины) -
vim.pack.add { gh 'tpope/vim-dadbod' }
vim.pack.add { gh 'kristijanhusak/vim-dadbod-ui' }

vim.g.db = default_url() -- dadbod: коннект по умолчанию для :DB
vim.g.db_default = { url = default_url() } -- dadbod-ui: то же для браузера
vim.g.db_ui_use_nerd_fonts = true

vim.keymap.set({ 'n', 'v' }, '<leader>qr', ':<C-U>DB<CR>', { desc = 'Run SQL query (Dadbod)' })
vim.keymap.set('n', '<leader>qd', '<cmd>DBUI<CR>', { desc = 'DB browser (Dadbod UI)' })

-- --- pgcli: интерактивный REPL в терминале -------------------------------
local function get_db_name()
  return os.getenv 'PGDATABASE' or os.getenv 'USER'
end

local function open_pgcli()
  local cmd = 'pgcli -d ' .. get_db_name()
  local ok, toggleterm = pcall(require, 'toggleterm')
  if ok then
    local Terminal = toggleterm.terminal.Terminal
    local term = Terminal:new { cmd = cmd, direction = 'float', close_on_exit = false }
    term:toggle()
  else
    -- фолбэк без toggleterm: нижний сплит
    vim.cmd.terminal(cmd)
    vim.cmd 'startinsert'
  end
end

vim.keymap.set('n', '<leader>qp', open_pgcli, { desc = 'Open pgcli REPL (float term)' })
vim.api.nvim_create_user_command('Pgsql', open_pgcli, { desc = 'Open pgcli REPL' })

return M