local M = {}

function M.setup(groups)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'sql', 'mysql', 'plsql', 'pgsql', 'psql' },
    group = groups.sql,
    callback = function()
      vim.bo.omnifunc = 'vim_dadbod_completion#omni'

      local ok, cmp = pcall(require, 'cmp')
      if ok then
        cmp.setup.buffer({
          sources = cmp.config.sources({
            { name = 'vim_dadbod-completion' },
          }, {
            { name = 'buffer' },
            { name = 'path' },
          }),
        })
      end
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'sql',
    group = groups.sql,
    callback = function()
      vim.keymap.set('n', '<F7>', 'vip<Plug>(DBUI_ExecuteQuery)', {
        buffer = true,
        desc = 'Execute SQL block with dbui',
        silent = true,
      })

      vim.keymap.set('v', '<F7>', '<Plug>(DBUI_ExecuteQuery)', {
        buffer = true,
        desc = 'Execute selected SQL with dbui',
        silent = true,
      })

      vim.keymap.set('i', '<F7>', '<Esc>vip<Plug>(DBUI_ExecuteQuery)', {
        buffer = true,
        desc = 'Execute SQL block with dbui',
        silent = true,
      })
    end,
  })
end

return M
