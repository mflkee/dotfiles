return {
  {
    'tiagovla/tokyodark.nvim',
    lazy = true,
    opts = {},
    config = function(_, opts)
      require('tokyodark').setup(opts)
    end,
  },
}
