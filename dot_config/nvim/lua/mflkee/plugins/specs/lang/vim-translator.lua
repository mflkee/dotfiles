return {
	{
		"voldikss/vim-translator",
		config = function()
			local cyrillic_pattern = vim.regex([=[\v[А-Яа-яЁё]]=])

			local function get_visual_selection()
				local start_pos = vim.fn.getpos("'<")
				local end_pos = vim.fn.getpos("'>")
				local start_row, start_col = start_pos[2], start_pos[3]
				local end_row, end_col = end_pos[2], end_pos[3]

				if start_row == 0 or end_row == 0 then
					return nil
				end

				if start_row > end_row or (start_row == end_row and start_col > end_col) then
					start_row, end_row = end_row, start_row
					start_col, end_col = end_col, start_col
				end

				local lines = vim.fn.getline(start_row, end_row)
				if vim.tbl_isempty(lines) then
					return nil
				end

				if start_row == end_row then
					lines[1] = string.sub(lines[1], start_col, end_col)
				else
					lines[1] = string.sub(lines[1], start_col)
					lines[#lines] = string.sub(lines[#lines], 1, end_col)
				end

				return table.concat(lines, "\n")
			end

			local function translate_visual_selection()
				local selection = get_visual_selection()
				if not selection or vim.trim(selection) == "" then
					vim.notify("Nothing selected for translation", vim.log.levels.WARN)
					return
				end

				local source_lang, target_lang = "en", "ru"
				if cyrillic_pattern:match_str(selection) then
					source_lang, target_lang = "ru", "en"
				end

				vim.cmd(("'<,'>Translate --source_lang=%s --target_lang=%s"):format(source_lang, target_lang))
			end

			vim.g.translator_source_lang = "auto"
			vim.g.translator_target_lang = "ru"
			vim.g.translator_default_engines = { "google", "bing" }

			vim.keymap.set("v", "<leader>t", translate_visual_selection, {
				noremap = true,
				silent = true,
				desc = "Translate selection ru/en",
			})
		end,
	},
}
