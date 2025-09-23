return {
  "tpope/vim-dadbod",
  "kristijanhusak/vim-dadbod-completion",
  "kristijanhusak/vim-dadbod-ui",
  config = function()
    -- Явно отключаем автоматическое выполнение
    vim.g.dadbod_auto_execute = 0
    vim.g.db_ui_auto_execute = 0
    
    -- Отключаем возможные авто-действия completion
    vim.g.vim_dadbod_completion_auto_execute = 0
  end,
}
