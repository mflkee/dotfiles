local M = {}

local function set_indent(width, use_spaces)
  vim.opt_local.tabstop = width
  vim.opt_local.shiftwidth = width
  vim.opt_local.softtabstop = width
  vim.opt_local.expandtab = use_spaces
  vim.opt_local.smartindent = false
  vim.opt_local.autoindent = true
end

function M.setup(groups)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'cpp', 'c', 'h', 'hpp' },
    group = groups.language,
    callback = function()
      set_indent(2, true)
      vim.opt_local.cinoptions = {
        ':0',
        'l1',
      }
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'json', 'jsonc', 'yaml', 'toml', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'lua' },
    group = groups.language,
    callback = function()
      set_indent(2, true)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'python', 'rust' },
    group = groups.language,
    callback = function()
      set_indent(4, true)
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = {
      'json',
      'jsonc',
      'yaml',
      'toml',
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
      'lua',
      'python',
      'rust',
      'cpp',
      'c',
    },
    group = groups.language,
    callback = function()
      vim.opt_local.formatoptions:remove({ 'c', 'r', 'o' })
    end,
  })
end

return M
