-- UI / Core UX plugins: guess-indent, gitsigns, which-key, bufferline,
-- colorscheme (cyberdream + base16/matugen), render-markdown, todo-comments,
-- mini.nvim modules.
local gh = require('mflkee.util').gh

-- [[ guess-indent: automatically detect and set the indentation ]]
vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
require('guess-indent').setup {}

-- [[ gitsigns: git signs in the gutter + utilities ]]
vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
local gitsigns = require 'gitsigns'
gitsigns.setup {
  signs = {
    add = { text = '+' }, ---@diagnostic disable-line: missing-fields
    change = { text = '~' }, ---@diagnostic disable-line: missing-fields
    delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
    topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
    changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
  },
  on_attach = function(bufnr)
    -- Navigation
    vim.keymap.set('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal { ']c', bang = true }
      else
        gitsigns.nav_hunk 'next'
      end
    end, { desc = 'Jump to next git [c]hange', buf = bufnr })

    vim.keymap.set('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal { '[c', bang = true }
      else
        gitsigns.nav_hunk 'prev'
      end
    end, { desc = 'Jump to previous git [c]hange', buf = bufnr })

    -- Visual mode actions
    vim.keymap.set('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk', buf = bufnr })
    vim.keymap.set('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk', buf = bufnr })
    -- Normal mode actions
    vim.keymap.set('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk', buf = bufnr })
    vim.keymap.set('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk', buf = bufnr })
    vim.keymap.set('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer', buf = bufnr })
    vim.keymap.set('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer', buf = bufnr })
    vim.keymap.set('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk', buf = bufnr })
    vim.keymap.set('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'git preview hunk [i]nline', buf = bufnr })
    vim.keymap.set('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line', buf = bufnr })
    vim.keymap.set('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index', buf = bufnr })
    vim.keymap.set('n', '<leader>hD', function() gitsigns.diffthis '~' end, { desc = 'git [D]iff against last commit', buf = bufnr })
    vim.keymap.set('n', '<leader>hQ', function() gitsigns.setqflist 'all' end, { desc = 'git hunk [Q]uickfix list (all files in repo)', buf = bufnr })
    vim.keymap.set('n', '<leader>hq', gitsigns.setqflist, { desc = 'git hunk [q]uickfix list (all changes in this file)', buf = bufnr })
    -- Toggles
    vim.keymap.set('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line', buf = bufnr })
    vim.keymap.set('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = '[T]oggle git intra-line [w]ord diff', buf = bufnr })
    -- Text object
    vim.keymap.set({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { desc = 'text object [i]nside [h]unk', buf = bufnr })
  end,
}

-- [[ which-key: shows pending keybinds ]]
vim.pack.add { gh 'folke/which-key.nvim' }
require('which-key').setup {
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
  spec = {
    { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    { 'gr', group = 'LSP Actions', mode = { 'n' } },
  },
}

-- [[ bufferline: buffer tabs at the top, cycle with `S-h` / `S-l` (or `]b`/`[b`) ]]
vim.pack.add { gh 'akinsho/bufferline.nvim' }
local bufferline = require 'bufferline'
bufferline.setup {
  options = {
    style_preset = bufferline.style_preset.no_italic,
    diagnostics = 'nvim_lsp',
  },
}
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next buffer' })
vim.keymap.set('n', ']b', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next buffer' })
vim.keymap.set('n', '[b', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>c', '<cmd>bdelete<cr>', { desc = 'Close buffer' })

-- [[ Colorscheme ]]
-- Ayu dark (base16-ayu) — общая палитра всей системы.
vim.pack.add { gh 'RRethy/base16-nvim' }
vim.cmd.colorscheme 'base16-ayu-dark'

-- [[ render-markdown: markdown preview rendering (github-style) ]]
vim.pack.add { gh 'nvim-tree/nvim-web-devicons' }
vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' }
require('render-markdown').setup {
  code = { sign = true, width = 'block', right_pad = 1 },
  heading = { sign = false, icons = {} },
  checkbox = { enabled = false },
}
vim.keymap.set('n', '<leader>um', '<cmd>RenderMarkdown toggle<cr>', { desc = 'Render Markdown' })

-- [[ todo-comments: highlight todo/note/etc in comments ]]
vim.pack.add { gh 'folke/todo-comments.nvim' }
require('todo-comments').setup { signs = false }

-- [[ mini.nvim: small independent modules ]]
vim.pack.add { gh 'nvim-mini/mini.nvim' }

-- Icons module (if a nerd font is available)
if vim.g.have_nerd_font then
  require('mini.icons').setup()
  -- Backwards compatibility for plugins that require `nvim-web-devicons`
  MiniIcons.mock_nvim_web_devicons()
end

-- Better Around/Inside textobjects
-- Examples: va) - [V]isually select [A]round [)]paren
require('mini.ai').setup {
  -- Avoid conflicts with the built-in incremental selection mappings on
  -- Neovim>=0.12 (see `:help treesitter-incremental-selection`)
  mappings = {
    around_next = 'aa',
    inside_next = 'ii',
  },
  n_lines = 500,
}

-- Add/delete/replace surroundings (brackets, quotes, etc.)
require('mini.surround').setup()

-- Simple statusline
local statusline = require 'mini.statusline'
statusline.setup { use_icons = vim.g.have_nerd_font }
---@diagnostic disable-next-line: duplicate-set-field
statusline.section_location = function() return '%2l:%-2v' end
