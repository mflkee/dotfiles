-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- LazyVim already moves lines on <A-j>/<A-k>; add Alt+Up/Down aliases.

-- swap current line with neighbor
vim.keymap.set("n", "<A-Up>", function()
	require("config.functions").move_line("up")
end, { desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", function()
	require("config.functions").move_line("down")
end, { desc = "Move line down" })

-- theme picker: all installed colorschemes (incl. lazy themes via :colorscheme auto-load)
local function list_colorschemes()
	local schemes = {}
	for _, name in ipairs(vim.fn.getcompletion("", "color")) do
		schemes[name] = true
	end
	for _, path in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/lazy/*/colors/*.{vim,lua}", true, true)) do
		schemes[vim.fn.fnamemodify(path, ":t:r")] = true
	end
	local list = vim.tbl_keys(schemes)
	table.sort(list)
	return list
end

local function theme_picker()
	local list = list_colorschemes()
	if #list == 0 then
		vim.notify("No colorschemes found", vim.log.levels.WARN)
		return
	end
	vim.ui.select(list, { prompt = "Colorscheme" }, function(choice)
		if choice then
			vim.cmd.colorscheme(choice)
		end
	end)
end

vim.keymap.set("n", "<leader>uC", theme_picker, { desc = "Theme picker" })
vim.api.nvim_create_user_command("ThemePicker", theme_picker, { desc = "Pick a colorscheme" })
