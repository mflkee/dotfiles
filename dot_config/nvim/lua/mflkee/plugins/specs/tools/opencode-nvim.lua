return {
	{
		"nickjvandyke/opencode.nvim",
		version = "*",
		config = function()
			---@type opencode.Opts
			vim.g.opencode_opts = {}

			vim.o.autoread = true

			vim.keymap.set({ "n", "t" }, "<M-c>", function()
				require("opencode").toggle()
			end, { desc = "Toggle opencode" })
		end,
	},
}
