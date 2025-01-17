return {

  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      vim.cmd 'colorscheme catppuccin'
      -- Дополнительные настройки, если нужно
    end,
    opts = {
      flavour = 'mocha', -- Устанавливаем цветовую схему 'mocha'
    },
  },
}
