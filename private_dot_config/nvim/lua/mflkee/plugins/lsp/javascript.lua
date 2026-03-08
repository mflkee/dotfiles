local M = {}

local function configure(server, cfg)
  if vim.lsp and vim.lsp.config then
    vim.lsp.config(server, cfg)
    vim.lsp.enable(server)
  else
    require('lspconfig')[server].setup(cfg)
  end
end

function M.setup(capabilities)
  local common = {
    capabilities = capabilities,
    on_attach = function(client)
      -- Formatting is handled by conform/prettier.
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
    filetypes = {
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
    },
  }

  local ok = pcall(configure, 'ts_ls', common)
  if not ok then
    ok = pcall(configure, 'tsserver', common)
  end

  if not ok then
    vim.notify('LSP config error: ts_ls/tsserver not available', vim.log.levels.ERROR)
  end
end

return M
