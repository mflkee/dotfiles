require("full-border"):setup()
require("git"):setup()

require("yatline"):setup({
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
