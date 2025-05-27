-- lua/mflkee/plugins/lsp/python.lua

M = {}

function M.setup(lspconfig, capabilities)
  lspconfig.pyright.setup {
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

  -- Новый официальный LSP-сервер от ruff
  lspconfig.ruff.setup {
    capabilities = capabilities,
    on_attach = function(client, _)
      -- Ruff не форматирует — только диагностика
      client.server_capabilities.documentFormattingProvider = false
    end,
    init_options = {
      settings = {
        args = {}, -- можно добавить аргументы для ruff здесь, если нужно
      },
    },
  }
end

return M
