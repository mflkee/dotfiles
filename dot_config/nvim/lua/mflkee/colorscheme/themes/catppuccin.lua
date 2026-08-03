return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = true,
    opts = {
      flavour = 'mocha',
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
    end,
  },
}
