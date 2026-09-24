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
--   <leader>qr  — выполнить выделенное/текущий запрос (dadbod)
--   <leader>qd  — открыть браузер БД (dadbod-ui)
--   <leader>qp  — открыть pgcli в плавающем терминале (или :Pgsql)
--
-- По умолчанию подключаемся к локальному кластеру PostgreSQL
-- (user == $USER, база == $PGDATABASE или $USER). Переопределить на лету:
--   :DB postgres://user:pass@host:5432/db
-- или переменными окружения для pgcli/dadbod (PGHOST, PGDATABASE, ...).

local M = {}

-- --- Соединение по умолчанию ------------------------------------------
local function default_url()
  local user = os.getenv 'USER'
  local db = os.getenv 'PGDATABASE' or user
  return string.format('postgres://%s@127.0.0.1:5432/%s?sslmode=disable', user, db)
end

-- --- lazy-спеки: dadbod + dadbod-ui -----------------------------------
-- custom/plugins грузятся в самом конце init.lua (после lazy.setup),
-- поэтому добавляем спеки через lazy.add — плагины установятся и будут
-- подгружаться лениво по командам/keymaps.
require('lazy').add({
  {
    'tpope/vim-dadbod',
    cmd = { 'DB', 'DBUI' },
    keys = {
      { '<leader>qr', ':<C-U>DB<CR>', mode = { 'n', 'v' }, desc = 'Run SQL query (Dadbod)' },
      { '<leader>qd', '<cmd>DBUI<CR>', desc = 'DB browser (Dadbod UI)' },
    },
    init = function()
      vim.g.db_default = { url = default_url() }
    end,
  },
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = { 'tpope/vim-dadbod' },
    cmd = { 'DBUI', 'DBUIToggle', 'DBUIAddConnection', 'DBUIFindBuffer', 'DBUIRenameBuffer', 'DBUILastQueryInfo' },
    init = function()
      vim.g.db_ui_use_nerd_fonts = true
      vim.g.db_ui_tmp_query_location = vim.fn.stdpath('data') .. '/dadbod_queries'
    end,
  },
})

-- --- pgcli: интерактивный REPL в терминале ------------------------------
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