-- lua/mflkee/plugins/neominimap.lua

return {
	"Isrothy/neominimap.nvim",
	version = "v3.*",
	lazy = false,
	keys = {
		{ "<leader>nm",  "<cmd>Neominimap Toggle<cr>",      desc = "Toggle global minimap" },
		{ "<leader>no",  "<cmd>Neominimap Enable<cr>",      desc = "Enable global minimap" },
		{ "<leader>nc",  "<cmd>Neominimap Disable<cr>",     desc = "Disable global minimap" },
		{ "<leader>nr",  "<cmd>Neominimap Refresh<cr>",     desc = "Refresh global minimap" },

		{ "<leader>nwt", "<cmd>Neominimap WinToggle<cr>",   desc = "Toggle window minimap" },
		{ "<leader>nwr", "<cmd>Neominimap WinRefresh<cr>",  desc = "Refresh window minimap" },
		{ "<leader>nwo", "<cmd>Neominimap WinEnable<cr>",   desc = "Enable window minimap" },
		{ "<leader>nwc", "<cmd>Neominimap WinDisable<cr>",  desc = "Disable window minimap" },

		{ "<leader>ntt", "<cmd>Neominimap TabToggle<cr>",   desc = "Toggle tab minimap" },
		{ "<leader>ntr", "<cmd>Neominimap TabRefresh<cr>",  desc = "Refresh tab minimap" },
		{ "<leader>nto", "<cmd>Neominimap TabEnable<cr>",   desc = "Enable tab minimap" },
		{ "<leader>ntc", "<cmd>Neominimap TabDisable<cr>",  desc = "Disable tab minimap" },

		{ "<leader>nbt", "<cmd>Neominimap BufToggle<cr>",   desc = "Toggle buffer minimap" },
		{ "<leader>nbr", "<cmd>Neominimap BufRefresh<cr>",  desc = "Refresh buffer minimap" },
		{ "<leader>nbo", "<cmd>Neominimap BufEnable<cr>",   desc = "Enable buffer minimap" },
		{ "<leader>nbc", "<cmd>Neominimap BufDisable<cr>",  desc = "Disable buffer minimap" },

		{ "<leader>nf",  "<cmd>Neominimap Focus<cr>",       desc = "Focus minimap" },
		{ "<leader>nu",  "<cmd>Neominimap Unfocus<cr>",     desc = "Unfocus minimap" },
		{ "<leader>ns",  "<cmd>Neominimap ToggleFocus<cr>", desc = "Toggle focus minimap" },
	},
	init = function()
		vim.opt.wrap = false
		vim.opt.sidescrolloff = 36
		vim.g.neominimap = { auto_enable = true }
	end,
}
