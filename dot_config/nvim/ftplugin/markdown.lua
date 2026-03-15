local fn = require 'mflkee.config.functions'

vim.opt_local.foldmethod = 'expr'
vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt_local.foldenable = true
vim.opt_local.foldlevel = 99
vim.opt_local.foldlevelstart = 99

vim.keymap.set('n', '<leader>o', fn.open_markdown_link_under_cursor, {
  buffer = 0,
  desc = 'Open markdown link under cursor',
  silent = true,
})
