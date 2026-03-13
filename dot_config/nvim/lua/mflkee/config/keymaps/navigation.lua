local fn = require 'mflkee.config.functions'

-- Window navigation and resizing.
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.keymap.set('n', '<A-h>', ':vertical resize -2<CR>', { desc = 'Decrease window width', silent = true })
vim.keymap.set('n', '<A-l>', ':vertical resize +2<CR>', { desc = 'Increase window width', silent = true })
vim.keymap.set('n', '<A-j>', ':resize +2<CR>', { desc = 'Increase window height', silent = true })
vim.keymap.set('n', '<A-k>', ':resize -2<CR>', { desc = 'Decrease window height', silent = true })

vim.keymap.set('n', '<leader>o', fn.open_file_under_cursor, { desc = 'Open file under cursor', silent = true })
