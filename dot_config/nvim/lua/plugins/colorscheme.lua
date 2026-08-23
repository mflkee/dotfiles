return {
	{
		"scottmckendry/cyberdream.nvim",
		priority = 1000,
		lazy = false,
		config = function()
			require("cyberdream").setup({})
			vim.cmd.colorscheme("cyberdream")
		end,
	},
	-- additional themes for the picker (lazy-loaded on demand via :colorscheme)
	{ "catppuccin/nvim", lazy = true },
	{ "rebelot/kanagawa.nvim", lazy = true },
	{ "sainnhe/gruvbox-material", lazy = true },
	{ "maxmx03/dracula.nvim", lazy = true },
	{ "Mofiqul/vscode.nvim", lazy = true },
}
