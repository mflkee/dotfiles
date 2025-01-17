return {
  -- Другие плагины

  -- Monokai Pro theme
  {
    'loctvl842/monokai-pro.nvim',
    lazy = false, -- Этот параметр гарантирует, что тема будет загружена сразу
    priority = 1000, -- Параметр для загрузки темы в первую очередь
    config = function()
      require('monokai-pro').setup()
      vim.cmd [[colorscheme monokai-pro]] -- Устанавливаем цветовую схему вручную
    end,
  },
}
