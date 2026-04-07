return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'williamboman/mason.nvim', config = true },
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'j-hui/fidget.nvim',
    'folke/neodev.nvim',
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    local function has_lua_ls()
      if vim.fn.executable('lua-language-server') == 1 then
        return true
      end

      local candidates = {
        vim.fn.expand('~/.local/bin/lua-language-server'),
        vim.fn.stdpath('data') .. '/mason/bin/lua-language-server',
        vim.fn.stdpath('data') .. '/mason/packages/lua-language-server/bin/lua-language-server',
      }

      for _, cmd in ipairs(candidates) do
        if vim.fn.executable(cmd) == 1 then
          return true
        end
      end

      return false
    end

    require('mason').setup({
      -- Ensure Mason bin dir is in PATH so servers launch
      PATH = 'prepend',
    })
    vim.g.mason_setup_done = true
    require('fidget').setup({})
    require('neodev').setup({})

    local ensure_installed = {
      'pyright',
      'typescript-language-server',
      'ruff',
      'black',
      'isort',
      'mypy',
      'codelldb',
    }

    if not has_lua_ls() then
      table.insert(ensure_installed, 1, 'lua-language-server')
    end

    require('mason-tool-installer').setup {
      ensure_installed = ensure_installed,
      run_on_start = true,
      start_delay = 3000,
      debounce_hours = 12,
    }

    -- Явная загрузка LSP-конфигов 
    local lsp_modules = {
      'lua_ls',
      'python',
      'javascript',
      -- Rust server lifecycle is handled by rustaceanvim, while this module
      -- prepares vim.g.rustaceanvim options.
      'rust',
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
