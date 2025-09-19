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

-- DB helpers for vim-dadbod / DBUI
function DBSetConnection()
  local input = vim.fn.input('DB (service name or full DSN): ')
  local function build_dsn(s)
    if s and s:match('://') then return s end
    if s and s ~= '' then return 'postgresql://?service=' .. s end
    if vim.env.PGSERVICE and vim.env.PGSERVICE ~= '' then
      return 'postgresql://?service=' .. vim.env.PGSERVICE
    end
    return nil
  end
  local dsn = build_dsn(input)
  if not dsn then
    vim.notify('DB: укажите сервис или DSN', vim.log.levels.WARN)
    return
  end
  vim.b.db = dsn
  vim.bo.filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'sql'
  vim.bo.omnifunc = 'vim_dadbod_completion#omni'
  vim.notify('DB: подключение для буфера установлено', vim.log.levels.INFO)
end

function DBNewQuery()
  vim.cmd('enew')
  vim.bo.filetype = 'sql'
  vim.bo.omnifunc = 'vim_dadbod_completion#omni'
  local default = vim.env.PGSERVICE or ''
  local svc = vim.fn.input('DB service (пусто = PGSERVICE): ', default)
  if svc ~= '' or (vim.env.PGSERVICE and vim.env.PGSERVICE ~= '') then
    local name = (svc ~= '' and svc) or vim.env.PGSERVICE
    vim.b.db = 'postgresql://?service=' .. name
  end
  vim.notify('DB: открыт новый SQL буфер', vim.log.levels.INFO)
end
