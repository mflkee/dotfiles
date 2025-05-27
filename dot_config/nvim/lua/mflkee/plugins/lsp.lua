-- lua/mflkee/plugins/lsp.lua

return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'williamboman/mason.nvim', config = true },
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'j-hui/fidget.nvim',
    'folke/neodev.nvim',
    'hrsh7th/nvim-cmp',
    { 'mrcjkb/rustaceanvim', version = '^4', ft = 'rust' },
  },
  config = function()
    local lspconfig = require 'lspconfig'
    local mason_lspconfig = require 'mason-lspconfig'
    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    require('mason').setup()

    require('mason-tool-installer').setup {
      ensure_installed = {
        -- LSP
        'lua-language-server',
        'pyright',
        'ruff',
        'rust-analyzer',
        -- Formatters, linters, debuggers
        'black',
        'isort',
        'mypy',
        'codelldb',
      },
    }

    -- Загружаем пользовательские конфиги из lua/mflkee/plugins/lsp/
    local lsp_dir = vim.fn.stdpath 'config' .. '/lua/mflkee/plugins/lsp'
    local custom_servers = {}

    local fd = vim.loop.fs_scandir(lsp_dir)
    if fd then
      while true do
        local file = vim.loop.fs_scandir_next(fd)
        if not file then
          break
        end
        local name = file:match '(.+)%.lua$'
        if name and name ~= 'init' then
          local ok, config = pcall(require, 'mflkee.plugins.lsp.' .. name)
          if ok and type(config.setup) == 'function' then
            config.setup(lspconfig, capabilities)
            table.insert(custom_servers, name)
          else
            vim.notify('Не удалось загрузить LSP конфиг: ' .. name, vim.log.levels.WARN)
          end
        end
      end
    end

    -- Обработка остальных серверов по умолчанию
    mason_lspconfig.setup {
      handlers = {
        function(server_name)
          if not vim.tbl_contains(custom_servers, server_name) then
            lspconfig[server_name].setup {
              capabilities = capabilities,
            }
          end
        end,
      },
    }
  end,
}
