local M = {}

function M.setup(groups)
  vim.api.nvim_create_autocmd('TermOpen', {
    desc = 'Remove numbers in terminal',
    group = groups.terminal,
    callback = function()
      vim.wo.number = false
      vim.wo.relativenumber = false
    end,
  })
end

return M
