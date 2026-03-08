local M = {}

function M.setup(groups)
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = groups.general,
    callback = function()
      vim.highlight.on_yank()
    end,
  })

  vim.api.nvim_create_autocmd('InsertLeave', {
    pattern = '*',
    group = groups.general,
    callback = function()
      if vim.fn.executable 'xkb-switch' == 1 then
        vim.system({ 'xkb-switch', '-s', 'us' }, { text = true }, function() end)
      end
    end,
  })
end

return M
