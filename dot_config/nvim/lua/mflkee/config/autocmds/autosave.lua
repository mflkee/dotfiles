local M = {}

function M.setup(groups)
  local timer = vim.uv.new_timer()
  local last_buf = -1

  local function autosave()
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    local buf = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buf) or buf ~= last_buf then
      return
    end

    local name = vim.api.nvim_buf_get_name(buf)
    if name == '' then
      return
    end

    local filetype = vim.bo[buf].filetype
    if filetype:match 'sql' then
      return
    end

    local buftype = vim.bo[buf].buftype
    if buftype ~= '' and buftype ~= 'acwrite' then
      return
    end

    if vim.bo[buf].readonly or not vim.bo[buf].modifiable then
      return
    end

    if vim.bo[buf].modified then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd 'silent! write'
      end)
    end
  end

  local function schedule()
    last_buf = vim.api.nvim_get_current_buf()
    timer:start(250, 0, vim.schedule_wrap(autosave))
  end

  vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged', 'TextChangedI' }, {
    group = groups.autosave,
    callback = schedule,
  })
end

return M
