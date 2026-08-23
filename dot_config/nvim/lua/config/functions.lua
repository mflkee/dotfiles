local M = {}

-- Swap the current line with the neighboring line (Alt+Up / Alt+Down).
function M.move_line(direction)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_line = cursor[1]
	local total_lines = vim.api.nvim_buf_line_count(0)

	local target_line
	if direction == "up" and current_line > 1 then
		target_line = current_line - 1
	elseif direction == "down" and current_line < total_lines then
		target_line = current_line + 1
	else
		return
	end

	local current_content = vim.api.nvim_get_current_line()
	local target_content = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)[1]

	vim.api.nvim_buf_set_lines(0, target_line - 1, target_line, false, { current_content })
	vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, { target_content })
	vim.api.nvim_win_set_cursor(0, { target_line, cursor[2] })
end

return M
