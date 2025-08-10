return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'williamboman/mason.nvim', config = true },
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'j-hui/fidget.nvim',
    'folke/neodev.nvim',
    'hrsh7th/nvim-cmp',
  },
  config = function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    require('mason').setup()
    require('fidget').setup({})
    require('neodev').setup({})

    require('mason-tool-installer').setup {
      ensure_installed = {
        'lua-language-server',
        'pyright',
        'ruff',
        'black',
        'isort',
        'mypy',
        'codelldb',
      },
    }

    -- Явная загрузка LSP-конфигов вместо динамического сканирования
    local lsp_servers = {
      'lua_ls',
      'python',
      'rust' -- rustaceanvim обрабатывает Rust отдельно
    }

    -- Загрузка конфигов
    for _, server in ipairs(lsp_servers) do
      local ok, config = pcall(require, 'mflkee.plugins.lsp.' .. server)
      if ok and type(config.setup) == 'function' then
        config.setup(capabilities)
      else
        vim.notify('LSP config error: ' .. server, vim.log.levels.ERROR)
      end
    end

    -- Базовые настройки для остальных LSP
    require('mason-lspconfig').setup({
      ensure_installed = {}, -- оставляем пустым, т.к. уже установили через tool-installer
      handlers = {
        function(server_name)
          -- Пропускаем уже настроенные серверы
          if not vim.tbl_contains(lsp_servers, server_name) then
            require('lspconfig')[server_name].setup({
              capabilities = capabilities
            })
          end
        end,
      }
    })
  end,
}
