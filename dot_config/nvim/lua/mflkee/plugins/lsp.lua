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
        'rust-analyzer',  -- Add rust-analyzer for rustaceanvim
      },
    }

    -- Явная загрузка LSP-конфигов 
    local lsp_modules = {
      'lua_ls',
      'python',
      -- Note: Rust is handled by rustaceanvim, so we don't load rust.lua here
      -- to avoid conflicts, but we keep the file in case it's needed for settings
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
