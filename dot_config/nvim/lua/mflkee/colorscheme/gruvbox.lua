return {
  'sainnhe/gruvbox-material',
  lazy = false,
  priority = 1000,
  config = function()
    vim.g.gruvbox_material_background = 'medium' -- soft, medium, hard
    vim.g.gruvbox_material_foreground = 'original' -- mix, original
  end,
}
