-- Snacks.nvim (folke, 2025): picker, notifier, dashboard, indent, image,
-- scratch, terminal, zen и др. Основной пикер вместо Telescope.
-- Telescope остаётся только ради vim.ui.select (см. plugins/search.lua).
local gh = require('mflkee.util').gh

vim.pack.add { gh 'folke/snacks.nvim' }

require('snacks').setup {
  bigfile = { enabled = true },
  dashboard = { enabled = true },
  image = { enabled = true }, -- ghostty поддерживает kitty-graphics протокол
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true, timeout = 4000 },
  picker = { enabled = true },
  quickfile = { enabled = true },
  scratch = { enabled = true },
  scroll = { enabled = true },
  terminal = { enabled = true },
  words = { enabled = true },
  zen = { enabled = true },
}

-- Дополнительные маппинги Snacks (основные пикеры — в plugins/search.lua)
vim.keymap.set('n', '<leader>.', function() Snacks.scratch() end, { desc = 'Toggle Scratch Buffer' })
vim.keymap.set('n', '<C-/>', function() Snacks.terminal() end, { desc = 'Toggle Terminal' })
vim.keymap.set('n', '<leader>z', function() Snacks.zen() end, { desc = 'Toggle Zen Mode' })
vim.keymap.set('n', '<leader>n', function() Snacks.notifier.show_history() end, { desc = 'Notification History' })

-- Git: lazygit во флоате (тема автоматически под цветовую схему) + GitHub browse
vim.keymap.set('n', '<leader>gg', function() Snacks.lazygit() end, { desc = 'Lazygit (float)' })
vim.keymap.set({ 'n', 'v' }, '<leader>gB', function() Snacks.gitbrowse() end, { desc = 'Git Browse (GitHub)' })
