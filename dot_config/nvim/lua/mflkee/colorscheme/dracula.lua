return {
	-- Установка плагина dracula.nvim
	{
		"maxmx03/dracula.nvim",
		lazy = false, -- Устанавливается сразу при запуске Neovim
		priority = 1000, -- Высокий приоритет, чтобы плагин загружался первым
		config = function()
			vim.cmd.colorscheme("dracula") -- Настроим Dracula как тему
		end,
	},
}
