-- Thin bootstrap: loads the mflkee module tree.
--
--   mflkee.options           — core options
--   mflkee.keymaps           — keymaps, diagnostics, terminal/cargo runner
--   mflkee.pack              — vim.pack build hooks (PackChanged autocmd)
--   mflkee.plugins.*         — plugin specs (vim.pack.add) grouped by area
--
-- Plus optional kickstart examples and personal custom plugins
-- (lua/custom/plugins/, auto-loaded from DSL-compatible specs).

vim.loader.enable()

-- Set <space> as the leader key (must happen before plugins are loaded)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require 'mflkee.options'
require 'mflkee.keymaps'
require 'mflkee.pack'

require 'mflkee.plugins.core'
require 'mflkee.plugins.snacks'
require 'mflkee.plugins.search'
require 'mflkee.plugins.lsp'
require 'mflkee.plugins.format'
require 'mflkee.plugins.completion'
require 'mflkee.plugins.treesitter'
require 'mflkee.plugins.oil'
require 'mflkee.plugins.flash'

-- Optional kickstart examples
require 'kickstart.plugins.debug'
require 'kickstart.plugins.indent_line'
require 'kickstart.plugins.lint'
require 'kickstart.plugins.autopairs'
require 'kickstart.plugins.neo-tree'

-- Custom plugins (dsync-capture, translate, sql). `custom.plugins` loads every
-- file in lua/custom/plugins/ (order unspecified — keep deps in one file).
require 'custom.plugins'

-- matugen → base16 dynamic colorscheme (wallpaper-driven; live-updates via
-- SIGUSR1). pcall-guarded so a not-yet-installed pack can never break startup.
local ok, matugen = pcall(require, 'matugen')
if ok then pcall(matugen.setup) end

-- vim: ts=2 sts=2 sw=2 et
