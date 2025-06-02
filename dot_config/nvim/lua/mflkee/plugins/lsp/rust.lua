local M = {}

function M.setup(_, _) -- lspconfig и capabilities не нужны здесь
	if vim.fn.executable("cargo") == 0 then
		vim.notify(
			"⚠️ Cargo не найден в $PATH: DAP и некоторые LSP-фичи могут не работать",
			vim.log.levels.WARN
		)
	end

	vim.g.rustaceanvim = {
		tools = {
			runnables = { use_telescope = true },
			inlay_hints = { auto = true },
		},
		server = {
			on_attach = function(_, bufnr)
				local opts = { buffer = bufnr }
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
			end,
			capabilities = require("cmp_nvim_lsp").default_capabilities(),
			settings = {
				["rust-analyzer"] = {
					cargo = { allFeatures = true },
					check = { command = "clippy" },
				},
			},
		},
		-- 🐞 DAP-конфиг: передаём таблицу типа "server"
		dap = {
			adapter = {
				type = "server", -- это server.Config
				port = "${port}", -- порт будет назначен динамически
				executable = {
					command = "codelldb", -- Mason устанавливает этот бинарник
					args = { "--port", "${port}" },
					detached = false,
				},
			},
		},
	}
end

return M
