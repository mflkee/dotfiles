return {
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
			"onsails/lspkind.nvim",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			local lspkind = require("lspkind")

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),
					["<C-y>"] = cmp.mapping.confirm({ select = true }),
					["<C-Space>"] = cmp.mapping.complete({}),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "path" },
				},
				formatting = {
					format = function(entry, vim_item)
						local max_label_width = 30
						if #vim_item.abbr > max_label_width then
							vim_item.abbr = vim_item.abbr:sub(1, max_label_width) .. "…"
						end
						return lspkind.cmp_format({
							mode = "symbol_text",
							maxwidth = 35,
							ellipsis_char = "...",
						})(entry, vim_item)
					end,
				},
				window = {
					completion = cmp.config.window.bordered({
						max_width = 40,
						col_offset = 0,
					}),
					documentation = cmp.config.window.bordered({
						max_width = 80,
						max_height = 20,
						col_offset = 40,
					}),
				},
			})
		end,
	},
}
