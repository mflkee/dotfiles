return {
  {
    'hardhackerlabs/theme-vim',
    name = 'hardhacker',
    lazy = true,
    config = function()
      vim.g.hardhacker_hide_tilde = 1
      vim.g.hardhacker_keyword_italic = 1
      vim.g.hardhacker_custom_highlights = {}
    end,
  },
}
