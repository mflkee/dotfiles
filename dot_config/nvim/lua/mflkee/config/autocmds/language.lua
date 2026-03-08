local M = {}

function M.setup(groups)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'cpp', 'c', 'h', 'hpp' },
    group = groups.language,
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.expandtab = true
      vim.opt_local.smartindent = false
      vim.opt_local.autoindent = true
      vim.opt_local.cinoptions = {
        ':0',
        'l1',
      }
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'lua' },
    group = groups.language,
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.expandtab = true
      vim.opt_local.smartindent = false
      vim.opt_local.autoindent = true
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'lua', 'python', 'rust', 'cpp', 'c' },
    group = groups.language,
    callback = function()
      vim.opt_local.formatoptions:remove({ 'c', 'r', 'o' })
    end,
  })
end

return M
