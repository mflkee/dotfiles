vim.opt.hlsearch = true           -- highlight search
vim.opt.number = true             -- line numbers
vim.opt.relativenumber = true     -- relative line numbers
vim.opt.mouse = "a"               -- mouse in all modes
vim.opt.clipboard = "unnamedplus" -- system clipboard
vim.opt.tabstop = 2               -- tab width
vim.opt.shiftwidth = 2            -- indentation amount
vim.opt.expandtab = true          -- convert tabs to spaces
vim.opt.smartindent = false       -- disable smartindent (use treesitter instead)
vim.opt.autoindent = true         -- standard autoindent
vim.opt.breakindent = true        -- wrap indent
vim.opt.undofile = true           -- persistent undo
vim.opt.ignorecase = true         -- case insensitive search
vim.opt.smartcase = true          -- case sensitive if uppercase used
vim.opt.signcolumn = "yes"        -- always show sign column
vim.opt.updatetime = 250          -- faster update time
vim.opt.timeoutlen = 300          -- faster key sequences
vim.opt.splitright = true         -- vertical split to the right
vim.opt.splitbelow = true         -- horizontal split below
vim.opt.inccommand = "split"      -- show substitution preview
vim.opt.cursorline = true         -- highlight current line
vim.opt.scrolloff = 10            -- scroll offset
vim.opt.termguicolors = true      -- enable 24-bit colors
vim.opt.foldmethod = "indent"     -- fold by indent
vim.opt.foldlevelstart = 99       -- start with all folds open
vim.opt.colorcolumn = "80"        -- show 80 char limit
vim.opt.list = false              -- don't show whitespace by default
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }  -- whitespace chars
vim.opt.completeopt = { "menu", "menuone", "noselect" }      -- completion options
vim.opt.showmode = false          -- don't show mode since statusline shows it

-- Consolidated indentation settings
vim.opt.smartindent = false       -- disable both indent options to use treesitter
vim.opt.autoindent = true         -- keep autoindent for basic functionality
