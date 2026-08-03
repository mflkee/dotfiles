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
      if vim.fn.executable 'lua-language-server' == 1 then
        return true
      end

      local candidates = {
        vim.fn.expand '~/.local/bin/lua-language-server',
        vim.fn.stdpath 'data' .. '/mason/bin/lua-language-server',
        vim.fn.stdpath 'data' .. '/mason/packages/lua-language-server/bin/lua-language-server',
      }

      for _, cmd in ipairs(candidates) do
        if vim.fn.executable(cmd) == 1 then
          return true
        end
      end

      return false
    end

    require('mason').setup {
      -- Ensure Mason bin dir is in PATH so servers launch
      PATH = 'prepend',
    }
    vim.g.mason_setup_done = true
    require('fidget').setup {}
    require('neodev').setup {}

    -- Global LSP keymaps: applied to any buffer with an attached client.
    -- (python/ts/lua configure no on_attach of their own, so this is the
    -- single source of truth; rustaceanvim clients are covered here too.)
    local lsp_augroup = vim.api.nvim_create_augroup('mflkee-lsp', { clear = true })
    vim.api.nvim_create_autocmd('LspAttach', {
      group = lsp_augroup,
      callback = function(args)
        local opts = { buffer = args.buf, silent = true }
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        vim.keymap.set('n', '<leader>ds', vim.lsp.buf.document_symbol, opts)
        vim.keymap.set('n', '<leader>ws', vim.lsp.buf.workspace_symbol, opts)
        vim.keymap.set('i', '<C-k>', vim.lsp.buf.signature_help, opts)
      end,
    })

    -- Only tools actually wired into the config. Python is formatted by
    -- ruff_format (conform), so black/isort/mypy were dead weight. codelldb
    -- is installed by mason-nvim-dap (kickstart/coding/debug.lua).
    local ensure_installed = {
      'pyright',
      'typescript-language-server',
      'ruff',
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
