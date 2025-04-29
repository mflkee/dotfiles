-- [[ Basic Keymaps ]]
-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next [D]iagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

vim.keymap.set({ "i", "n" }, "<m-i>", "<esc>i```{python}<cr>```<esc>O", { desc = "[i]nser code chunk" })
vim.keymap.set({ "n" }, "<leader>ci", ":split term://ipython<cr>", { desc = "split terminal" })

-- set buffer
vim.keymap.set("n", "b[", ":bprev<CR>", { desc = "Go to previous buffer" })
vim.keymap.set("n", "b]", ":bnext<CR>", { desc = "Go to next buffer" })
vim.keymap.set("n", "bx", ":bdelete<CR>", { desc = "Close current buffer" })
vim.keymap.set("n", "bc", function()
	local input = vim.fn.input("Enter file name: ")
	if input ~= "" then
		vim.cmd("edit " .. input)
	end
end, { desc = "Create and open new file" })

-- Настройка сочетаний клавиш для изменения размера окон
vim.api.nvim_set_keymap("n", "<A-h>", ":vertical resize -2<CR>", { noremap = true, silent = true }) -- Уменьшение ширины
vim.api.nvim_set_keymap("n", "<A-l>", ":vertical resize +2<CR>", { noremap = true, silent = true }) -- Увеличение ширины
vim.api.nvim_set_keymap("n", "<A-j>", ":resize +2<CR>", { noremap = true, silent = true }) -- Увеличение высоты
vim.api.nvim_set_keymap("n", "<A-k>", ":resize -2<CR>", { noremap = true, silent = true }) -- Уменьшение высоты

vim.keymap.set("n", "<leader>R", function()
	local filetype = vim.bo.filetype
	local current_file = vim.fn.expand("%:p") -- Полный путь к текущему файлу
	local dir = vim.fn.expand("%:p:h") -- Директория текущего файла

	if filetype == "rust" then
		-- Запуск Rust-кода через cargo run
		vim.cmd("TermExec cmd='cargo run' dir=" .. dir)
	elseif filetype == "python" then
		-- Запуск Python-кода
		vim.cmd("TermExec cmd='python " .. current_file .. "'")
	elseif filetype == "quarto" then
		-- Предпросмотр Quarto
		vim.cmd("QuartoPreview")
	elseif filetype == "cpp" then
		-- Компиляция и запуск C++ кода
		local output_file = vim.fn.expand("%:p:r") -- Убираем расширение файла
		local executable = vim.fn.fnamemodify(output_file, ":t") -- Только имя исполняемого файла (без пути)
		vim.cmd(
			"TermExec cmd='cd "
				.. dir
				.. " && g++ -o "
				.. executable
				.. " "
				.. current_file
				.. " && ./"
				.. executable
				.. "'"
		)
	else
		-- Если тип файла не поддерживается
		vim.notify("Unsupported filetype: " .. filetype, vim.log.levels.WARN)
	end
end, { desc = "[R]un code based on filetype" })

-- открыть файл под курсором
vim.api.nvim_set_keymap("n", "<leader>o", ":lua OpenFileUnderCursor()<CR>", { noremap = true, silent = true })

-- поменять метсами строчки
vim.api.nvim_set_keymap("n", "<A-Up>", '<cmd>lua MoveLine("up")<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-Down>", '<cmd>lua MoveLine("down")<CR>', { noremap = true, silent = true })

-- hex
vim.keymap.set("n", "<leader>hx", ":HexToggle<CR>", { desc = "Toggle hex view" })

--plantuml
-- Для PlantUML Previewer
vim.api.nvim_set_keymap('n', '<leader>pu', ':PlantumlOpen<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>ps', ':PlantumlSave<CR>', { noremap = true, silent = true })
