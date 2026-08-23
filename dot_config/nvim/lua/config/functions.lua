local M = {}

local colorscheme_state = vim.fn.stdpath 'state' .. '/colorscheme.txt'

function M.get_saved_colorscheme()
  if vim.fn.filereadable(colorscheme_state) == 0 then
    return nil
  end
  local name = vim.trim(vim.fn.readfile(colorscheme_state)[1] or '')
  return name ~= '' and name or nil
end

function M.save_colorscheme(name)
  vim.fn.writefile({ name }, colorscheme_state)
end

function M.apply_colorscheme(name)
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(('Colorscheme %q failed: %s'):format(name, err), vim.log.levels.WARN)
  end
  return ok
end

-- Swap the current line with the neighboring line (Alt+Up / Alt+Down).
function M.move_line(direction)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]
  local total_lines = vim.api.nvim_buf_line_count(0)

  local target_line
  if direction == 'up' and current_line > 1 then
    target_line = current_line - 1
  elseif direction == 'down' and current_line < total_lines then
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
