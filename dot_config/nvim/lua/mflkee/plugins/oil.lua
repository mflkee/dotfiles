-- Oil.nvim: vim-fайловый менеджер (редактируй пути как текст).
local gh = require('mflkee.util').gh

vim.pack.add { gh 'stevearc/oil.nvim' }
require('oil').setup {
  default_file_explorer = false, -- neo-tree остаётся основным деревом
}

vim.keymap.set('n', '-', '<cmd>Oil<CR>', { desc = 'Open parent directory (Oil)' })
