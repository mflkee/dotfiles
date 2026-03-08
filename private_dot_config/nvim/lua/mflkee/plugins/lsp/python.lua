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
  configure('pyright', {
    capabilities = capabilities,
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = 'openFilesOnly',
        },
      },
    },
  })

  configure('ruff', {
    capabilities = capabilities,
    on_attach = function(client)
      client.server_capabilities.documentFormattingProvider = false
    end,
  })
end

return M
