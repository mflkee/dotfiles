local M = {}

function M.setup(groups)
  vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { '*.cpp', '*.c', '*.h', '*.hpp' },
    group = groups.format,
    callback = function()
      local ok, conform = pcall(require, 'conform')
      if ok then
        conform.format({ async = false, lsp_fallback = true })
      end
    end,
  })
end

return M
