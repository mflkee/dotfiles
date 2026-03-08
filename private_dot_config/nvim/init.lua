vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true
vim.opt.guifont = "Lilex Nerd Font Mono:h12"


-- [[configs]]
require("mflkee.config.options")
-- функции должны грузиться до keymaps, т.к. часть маппингов вызывает их
require("mflkee.config.functions")
require("mflkee.config.keymaps")
require("mflkee.config.autocmds")

-- [[ Install `lazy.nvim` plugin manager ]]
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({

require("kickstart.plugins.coding.debug"),
require("kickstart.plugins.editor.indent_line"),
require("kickstart.plugins.coding.lint"),
require("kickstart.plugins.editor.autopairs"),
require("kickstart.plugins.navigation.neo-tree"),
require("kickstart.plugins.git.gitsigns"), -- adds gitsigns recommend keymaps
	{ import = "mflkee.plugins.specs.ui" },
	{ import = "mflkee.plugins.specs.lsp" },
	{ import = "mflkee.plugins.specs.lang" },
	{ import = "mflkee.plugins.specs.tools" },
	{ import = "mflkee.colorscheme.themes" },
}, {
  -- Move lockfile out of config so chezmoi can ignore it easily
  lockfile = vim.fn.stdpath("data") .. "/lazy/lazy-lock.json",
  ui = {
		-- If you are using a Nerd Font: set icons to an empty table which will use the
		-- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤",
		},
  },
})

require("mflkee.colorswitcher").setup()

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
