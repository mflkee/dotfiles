-- Improved functions with better error handling:

-- Simpler file opening function
function OpenFileUnderCursor()
    local filepath = vim.fn.expand("<cfile>")
    if vim.fn.filereadable(filepath) == 1 then
        vim.cmd("edit " .. filepath)
    else
        vim.notify("File not found: " .. filepath, vim.log.levels.WARN)
    end
end

-- More efficient line moving function
function MoveLine(direction)
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local total_lines = vim.api.nvim_buf_line_count(0)
    
    local target_line
    if direction == "up" and current_line > 1 then
        target_line = current_line - 1
    elseif direction == "down" and current_line < total_lines then
        target_line = current_line + 1
    else
        return -- No movement possible
    end
    
    -- Get both lines
    local current_content = vim.api.nvim_get_current_line()
    local target_content = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)[1]
    
    -- Swap lines
    vim.api.nvim_buf_set_lines(0, target_line - 1, target_line, false, { current_content })
    vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, { target_content })
    
    -- Move cursor to target line
    vim.api.nvim_win_set_cursor(0, { target_line, vim.api.nvim_win_get_cursor(0)[2] })
end

-- DB helpers (keeping as is, they're well implemented)
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
