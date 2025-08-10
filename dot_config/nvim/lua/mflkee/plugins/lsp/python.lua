local M = {}

function M.setup(capabilities)
  require('lspconfig').pyright.setup {
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
  }

  require('lspconfig').ruff.setup {
    capabilities = capabilities,
    on_attach = function(client)
      client.server_capabilities.documentFormattingProvider = false
    end,
  }
end

return M
