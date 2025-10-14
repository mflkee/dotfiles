return {
  -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  opts = {
    ensure_installed = {
      'bash',
      'c',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'vim',
      'vimdoc',
      'cpp',
      'rust',
      'python',
    },
    -- Autoinstall languages that are not installed
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = { 'ruby' },
    },
    indent = {
      enable = true,
      disable = { 'ruby' },
    },
    incremental_selection = {
      enable = true,
    },
    textobjects = {
      select = {
        enable = true,
      },
      move = {
        enable = true,
      },
      swap = {
        enable = true,
      },
      lsp_interop = {
        enable = true,
      },
    },
  },
  config = function(_, opts)
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

    -- Prefer git instead of curl in order to improve connectivity in some environments
    require('nvim-treesitter.install').prefer_git = true
    ---@diagnostic disable-next-line: missing-fields
    require('nvim-treesitter.configs').setup(opts)

    if vim.tbl_contains(opts.ensure_installed or {}, 'python') then
      local query = vim.treesitter and vim.treesitter.query
      if query and query.get and query.set then
        local ok, err = pcall(query.get, 'python', 'highlights')
        if not ok and err:find('Invalid node type "except%*"') then
          local files = vim.api.nvim_get_runtime_file('queries/python/highlights.scm', true)
          if #files > 0 then
            local parts = {}
            for _, path in ipairs(files) do
              local read_ok, lines = pcall(vim.fn.readfile, path)
              if read_ok then
                table.insert(parts, table.concat(lines, '\n'))
              end
            end
            local patched = table.concat(parts, '\n'):gsub('\n%s*"except%*"%s*\n', '\n')
            local set_ok, set_err = pcall(query.set, 'python', 'highlights', patched)
            if not set_ok then
              vim.schedule(function()
                vim.notify('Failed to patch python treesitter query: ' .. set_err, vim.log.levels.WARN)
              end)
            end
          end
        end
      end
    end

    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  end,
}
