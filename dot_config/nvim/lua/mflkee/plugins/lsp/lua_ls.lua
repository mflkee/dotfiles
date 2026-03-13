local M = {}

local function configure(server, cfg)
  if vim.lsp and vim.lsp.config then
    vim.lsp.config(server, cfg)
    vim.lsp.enable(server)
  else
    require('lspconfig')[server].setup(cfg)
  end
end

local function resolve_lua_ls_cmd()
  -- Use PATH command when available.
  if vim.fn.executable('lua-language-server') == 1 then
    return nil
  end

  local candidates = {
    vim.fn.expand('~/.local/bin/lua-language-server'),
    vim.fn.stdpath('data') .. '/mason/bin/lua-language-server',
    vim.fn.stdpath('data') .. '/mason/packages/lua-language-server/bin/lua-language-server',
  }

  for _, cmd in ipairs(candidates) do
    if vim.fn.executable(cmd) == 1 then
      return { cmd }
    end
  end

  return nil
end

function M.setup(capabilities)
  local cmd = resolve_lua_ls_cmd()

  configure('lua_ls', {
    capabilities = capabilities,
    cmd = cmd,
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
