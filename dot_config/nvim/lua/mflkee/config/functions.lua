-- Функция для открытия файла под курсором
function OpenFileUnderCursor()
	local filepath = vim.fn.expand("<cfile>")
	vim.cmd("edit " .. filepath)
end

-- Функция для перемещения строки вверх или вниз
function MoveLine(direction)
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local total_lines = vim.api.nvim_buf_line_count(0)

	if (direction == "up" and current_line > 1) or (direction == "down" and current_line < total_lines) then
		local line_content = vim.api.nvim_get_current_line()
		local target_line = direction == "up" and current_line - 1 or current_line + 1

		-- Получить содержимое целевой строки
		local target_content = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)[1]

		-- Поменять местами строки
		vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, { target_content })
		vim.api.nvim_buf_set_lines(0, target_line - 1, target_line, false, { line_content })

		-- Переместить курсор на новую строку
		vim.api.nvim_win_set_cursor(0, { target_line, 0 })
	end
end
