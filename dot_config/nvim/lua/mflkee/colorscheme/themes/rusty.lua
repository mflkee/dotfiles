return {
  {
    'armannikoyan/rusty',
    lazy = false,
    priority = 1000,
    opts = {},
    config = function(_, opts)
      require('rusty').setup(opts)
    end,
  },
}
