-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd('TermOpen', {
  desc = 'remove numbers line in terminal',
  group = vim.api.nvim_create_augroup('kickstart-term', { clear = true }),
  callback = function()
    vim.wo.number = false
  end,
})

-- Переключение на английскую раскладку при выходе из режима вставки
vim.api.nvim_create_autocmd('InsertLeave', {
  pattern = '*',
  callback = function()
    os.execute 'xkb-switch -s us'
  end,
})
