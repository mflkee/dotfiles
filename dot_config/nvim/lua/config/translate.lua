local M = {}

local cyrillic = vim.regex([=[\v[А-Яа-яЁё]]=])
local preview_max_height = 10

local function ensure_globals()
	if not vim.g.translator_source_lang then
		vim.g.translator_source_lang = "auto"
	end
	if not vim.g.translator_target_lang then
		vim.g.translator_target_lang = "ru"
	end
	if not vim.g.translator_default_engines then
		vim.g.translator_default_engines = { "google", "bing" }
	end
end

local function configure_window()
	vim.g.translator_window_type = "preview"
	vim.g.translator_window_max_width = math.max(1, vim.api.nvim_win_get_width(0) - 4)
	vim.g.translator_window_max_height = preview_max_height
end

local function get_selection()
	local mode = vim.fn.mode()
	if mode == "\22" then
		vim.notify("Blockwise translation is not supported", vim.log.levels.WARN)
		return nil
	end

	local start_pos = vim.fn.getpos("v")
	local cursor = vim.api.nvim_win_get_cursor(0)
	local start_row, start_col = start_pos[2], start_pos[3]
	local end_row, end_col = cursor[1], cursor[2] + 1

	if start_row == 0 or end_row == 0 then
		return nil
	end
	if mode == "V" then
		start_col, end_col = 1, #vim.fn.getline(end_row)
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

local function translate(text, display_mode)
	if not text or vim.trim(text) == "" then
		vim.notify("Nothing to translate", vim.log.levels.WARN)
		return
	end

	ensure_globals()
	local source_lang, target_lang = "en", "ru"
	if cyrillic:match_str(text) then
		source_lang, target_lang = "ru", "en"
	end
	if display_mode == "window" then
		configure_window()
	end

	vim.fn["translator#logger#init"]()
	vim.fn["translator#translate"]({
		text = vim.fn["translator#util#text_proc"](text),
		source_lang = source_lang,
		target_lang = target_lang,
		engines = vim.g.translator_default_engines,
	}, display_mode)
end

function M.visual(display_mode)
	translate(get_selection(), display_mode)
end

function M.word(display_mode)
	translate(vim.fn.expand("<cword>"), display_mode)
end

return M
