require("full-border"):setup()
require("git"):setup()

-- Yatline рисует верхнюю (header) и нижнюю (status) строки yazi. Без явной
-- темы он берёт свои чёрно-белые умолчания (style_a/b/c = white/black),
-- поэтому бары не совпадали с flavor `noctalia` (ayu-палитра) у списка файлов.
-- Ниже — та же палитра, что в flavors/noctalia.yazi/flavor.toml.
require("yatline"):setup({
	theme = {
		style_a = {
			bg = "#e6b450",
			fg = "#0b0e14",
			bg_mode = {
				normal = "#e6b450",
				select = "#aad94c",
				un_set = "#39bae6",
			},
		},
		style_b = { bg = "#1e222a", fg = "#d1d1c7" },
		style_c = { bg = "#0b0e14", fg = "#d1d1c7" },

		permissions_t_fg = "#aad94c",
		permissions_r_fg = "#e6b450",
		permissions_w_fg = "#d95757",
		permissions_x_fg = "#39bae6",
		permissions_s_fg = "#76530e",
		-- Иконки/цвета счётчиков (selected/copied/cut/files/total/...) не
		-- переопределяем — дефолтные жёлтый/зелёный/красный/синий подходят.
	},
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
})

require("whoosh"):setup({
	bookmarks = {
		{ tag = "Projects",  key = "p", path = "~/projects/" },
		{ tag = "Documents", key = "d", path = "~/Documents/" },
		{ tag = "Obsidian",  key = "n", path = "~/obs_main/" },
	},
	jump_notify = false,
	keys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
	home_alias_enabled = true,
})
