return {
  {
    'sainnhe/sonokai',
    name = 'sonokai',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.sonokai_style = 'andromeda'
      vim.g.sonokai_enable_italic = 1
      vim.g.sonokai_diagnostic_text_highlight = 1
    end,
  },
}
