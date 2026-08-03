return {
  -- Другие плагины

  -- Monokai Pro theme
  {
    'loctvl842/monokai-pro.nvim',
    lazy = true,
    config = function()
      require('monokai-pro').setup()
    end,
  },
}
