local fn = require 'mflkee.config.functions'

-- Hex and PlantUML helpers.
vim.keymap.set('n', '<leader>hx', ':HexToggle<CR>', { desc = 'Toggle hex view' })
vim.keymap.set('n', '<leader>pu', ':PlantumlOpen<CR>', { desc = 'Open PlantUML' })
vim.keymap.set('n', '<leader>ps', ':PlantumlSave<CR>', { desc = 'Save PlantUML' })

-- DBUI workflow.
vim.keymap.set('n', '<leader>dbu', ':DBUI<CR>', { desc = '[DB] Open UI' })
vim.keymap.set('n', '<leader>dbt', ':DBUIToggle<CR>', { desc = '[DB] Toggle UI' })
vim.keymap.set('n', '<leader>dba', ':DBUIAddConnection<CR>', { desc = '[DB] Add connection' })
vim.keymap.set('n', '<leader>dbb', ':DBUIFindBuffer<CR>', { desc = '[DB] Find buffer' })
vim.keymap.set('n', '<leader>dbn', fn.db_new_query, { desc = '[DB] New SQL buffer' })
vim.keymap.set('n', '<leader>dbc', fn.db_set_connection, { desc = '[DB] Set buffer connection' })
