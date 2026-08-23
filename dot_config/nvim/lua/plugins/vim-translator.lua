---@type LazySpec
return {
	{
		"voldikss/vim-translator",
		build = "python3 -m pip install requests",
		-- functions run AFTER the plugin is loaded, so the first press works too.
		-- note: lazy `keys` format is { lhs, rhs, opts } — mode goes in opts.
		keys = {
			{
				"<Leader>t",
				function()
					require("config.translate").visual("window")
				end,
				mode = "v",
				desc = "Translate selection (window)",
			},
			{
				"<Leader>T",
				function()
					require("config.translate").visual("echo")
				end,
				mode = "v",
				desc = "Translate selection (echo)",
			},
			{
				"<Leader>tw",
				function()
					require("config.translate").word("window")
				end,
				desc = "Translate word (window)",
			},
			{
				"<Leader>tW",
				function()
					require("config.translate").word("echo")
				end,
				desc = "Translate word (echo)",
			},
		},
	},
}
