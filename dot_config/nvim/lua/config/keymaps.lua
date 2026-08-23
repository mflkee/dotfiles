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
