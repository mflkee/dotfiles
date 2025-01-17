return {
  'sainnhe/gruvbox-material',
  config = function()
    --Установите тему
    vim.cmd 'colorscheme gruvbox-material'

    -- Дополнительные настройки (необязательно)
    vim.g.gruvbox_material_background = 'medium' -- Опции: soft, medium, hard
    vim.g.gruvbox_material_foreground = 'original' -- Опции: mix, original
  end,
}
