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
  configure('lua_ls', {
    capabilities = capabilities,
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        diagnostics = { globals = { 'vim' } },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file('', true),
        },
        telemetry = { enable = false },
      },
    },
  })
end

return M
