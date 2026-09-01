-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- LazyVim already moves lines on <A-j>/<A-k>; add Alt+Up/Down aliases.

-- swap current line with neighbor
vim.keymap.set('n', '<A-Up>', function()
  require('config.functions').move_line 'up'
end, { desc = 'Move line up' })
vim.keymap.set('n', '<A-Down>', function()
  require('config.functions').move_line 'down'
end, { desc = 'Move line down' })

-- translate selection (window / echo)
vim.keymap.set('v', '<Leader>t', function()
  require('config.translate').visual 'window'
end, { desc = 'Translate selection (window)' })
vim.keymap.set('v', '<Leader>T', function()
  require('config.translate').visual 'echo'
end, { desc = 'Translate selection (echo)' })
-- translate word under cursor (window / echo)
vim.keymap.set('n', '<Leader>tw', function()
  require('config.translate').word 'window'
end, { desc = 'Translate word (window)' })
vim.keymap.set('n', '<Leader>tW', function()
  require('config.translate').word 'echo'
end, { desc = 'Translate word (echo)' })
