local fn = require 'mflkee.config.functions'

-- Buffer workflow.
vim.keymap.set('n', '<leader>bp', ':bprev<CR>', { desc = '[B]uffer: previous' })
vim.keymap.set('n', '<leader>bn', ':bnext<CR>', { desc = '[B]uffer: next' })
vim.keymap.set('n', '<leader>bd', ':bdelete<CR>', { desc = '[B]uffer: delete' })
vim.keymap.set('n', '<leader>bc', function()
  local input = vim.fn.input 'Enter file name: '
  if input ~= '' then
    vim.api.nvim_cmd({ cmd = 'edit', args = { input } }, {})
  end
end, { desc = '[B]uffer: create new file' })

-- Line movement helpers.
vim.keymap.set('n', '<A-Up>', function()
  fn.move_line 'up'
end, { desc = 'Move line up', silent = true })
vim.keymap.set('n', '<A-Down>', function()
  fn.move_line 'down'
end, { desc = 'Move line down', silent = true })
