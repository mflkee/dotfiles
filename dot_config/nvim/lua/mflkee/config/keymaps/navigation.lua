local fn = require 'mflkee.config.functions'

-- Window navigation is handled by vim-tmux-navigator (<C-h/j/k/l>), which
-- falls back to native window movement when not inside tmux. Only resizing
-- and misc helpers live here.
vim.keymap.set('n', '<A-h>', ':vertical resize -2<CR>', { desc = 'Decrease window width', silent = true })
vim.keymap.set('n', '<A-l>', ':vertical resize +2<CR>', { desc = 'Increase window width', silent = true })
vim.keymap.set('n', '<A-j>', ':resize +2<CR>', { desc = 'Increase window height', silent = true })
vim.keymap.set('n', '<A-k>', ':resize -2<CR>', { desc = 'Decrease window height', silent = true })

vim.keymap.set('n', '<leader>o', fn.open_file_under_cursor, { desc = 'Open file under cursor', silent = true })
