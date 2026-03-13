local M = {}

function M.setup(groups)
  vim.api.nvim_create_autocmd('BufNewFile', {
    pattern = '*.puml',
    group = groups.plantuml,
    callback = function()
      local lines = {
        '@startuml',
        '!include /home/mflkee/.config/plantuml/dracula.puml',
        '',
        '@enduml',
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
    end,
  })
end

return M
