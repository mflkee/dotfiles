return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'williamboman/mason.nvim', config = true },
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'j-hui/fidget.nvim',
    'folke/neodev.nvim',
    'hrsh7th/nvim-cmp',
  },
  config = function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    require('mason').setup({
      -- Ensure Mason bin dir is in PATH so servers launch
      PATH = 'prepend',
    })
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

    -- Явная загрузка LSP-конфигов через vim.lsp.config/vim.lsp.enable
    local lsp_modules = {
      'lua_ls',
      'python',
      'rust',   -- rustaceanvim обрабатывает Rust отдельно
    }

    for _, mod in ipairs(lsp_modules) do
      local ok, m = pcall(require, 'mflkee.plugins.lsp.' .. mod)
      if ok and type(m.setup) == 'function' then
        m.setup(capabilities)
      else
        vim.notify('LSP config error: ' .. mod, vim.log.levels.ERROR)
      end
    end
  end,
}
