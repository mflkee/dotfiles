-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands` Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("TermOpen", {
	desc = "remove numbers line in terminal",
	group = vim.api.nvim_create_augroup("kickstart-term", { clear = true }),
	callback = function()
		vim.wo.number = false
	end,
})

-- Переключение на английскую раскладку при выходе из режима вставки
vim.api.nvim_create_autocmd("InsertLeave", {
	pattern = "*",
	callback = function()
		os.execute("xkb-switch -s us")
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.cpp",
	callback = function()
		require("conform").format({ async = true, lsp_fallback = true })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "cpp", "c", "h", "hpp" }, -- Файлы C++
	callback = function()
		vim.opt_local.tabstop = 2 -- Размер табуляции
		vim.opt_local.shiftwidth = 2 -- Размер отступа
		vim.opt_local.expandtab = true -- Преобразовывать Tab в пробелы
		vim.opt_local.smartindent = false -- Отключить умные отступы
		vim.opt_local.autoindent = false -- Отключить автоиндентацию
		vim.opt_local.cinoptions = {
			":0", -- Не добавлять дополнительные отступы после `{`
			"l1", -- Уровень отступа для `{` и `}`
		}
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "lua" }, -- Файлы Lua
	callback = function()
		vim.opt_local.tabstop = 2 -- Размер табуляции
		vim.opt_local.shiftwidth = 2 -- Размер отступа
		vim.opt_local.expandtab = true -- Преобразовывать Tab в пробелы
		vim.opt_local.smartindent = false -- Отключить умные отступы
		vim.opt_local.autoindent = false -- Отключить автоиндентацию
	end,
})
