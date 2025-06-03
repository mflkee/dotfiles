-- lua/mflkee/plugins/neominimap.lua

return {
	"Isrothy/neominimap.nvim",
	version = "v3.*",
	lazy = false,
	keys = {
		{ "<leader>nm", "<cmd>Neominimap Toggle<cr>", desc = "Toggle global minimap" },
		{ "<leader>no", "<cmd>Neominimap on<cr>", desc = "Enable global minimap" },
		{ "<leader>nc", "<cmd>Neominimap off<cr>", desc = "Disable global minimap" },
		{ "<leader>nr", "<cmd>Neominimap refresh<cr>", desc = "Refresh global minimap" },

		{ "<leader>nwt", "<cmd>Neominimap winToggle<cr>", desc = "Toggle window minimap" },
		{ "<leader>nwr", "<cmd>Neominimap winRefresh<cr>", desc = "Refresh window minimap" },
		{ "<leader>nwo", "<cmd>Neominimap winOn<cr>", desc = "Enable window minimap" },
		{ "<leader>nwc", "<cmd>Neominimap winOff<cr>", desc = "Disable window minimap" },

		{ "<leader>ntt", "<cmd>Neominimap tabToggle<cr>", desc = "Toggle tab minimap" },
		{ "<leader>ntr", "<cmd>Neominimap tabRefresh<cr>", desc = "Refresh tab minimap" },
		{ "<leader>nto", "<cmd>Neominimap tabOn<cr>", desc = "Enable tab minimap" },
		{ "<leader>ntc", "<cmd>Neominimap tabOff<cr>", desc = "Disable tab minimap" },

		{ "<leader>nbt", "<cmd>Neominimap bufToggle<cr>", desc = "Toggle buffer minimap" },
		{ "<leader>nbr", "<cmd>Neominimap bufRefresh<cr>", desc = "Refresh buffer minimap" },
		{ "<leader>nbo", "<cmd>Neominimap bufOn<cr>", desc = "Enable buffer minimap" },
		{ "<leader>nbc", "<cmd>Neominimap bufOff<cr>", desc = "Disable buffer minimap" },

		{ "<leader>nf", "<cmd>Neominimap focus<cr>", desc = "Focus minimap" },
		{ "<leader>nu", "<cmd>Neominimap unfocus<cr>", desc = "Unfocus minimap" },
		{ "<leader>ns", "<cmd>Neominimap toggleFocus<cr>", desc = "Toggle focus minimap" },
	},
	init = function()
		vim.opt.wrap = false
		vim.opt.sidescrolloff = 36
		vim.g.neominimap = { auto_enable = true }
	end,
}
