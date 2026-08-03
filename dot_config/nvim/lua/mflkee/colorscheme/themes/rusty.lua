return {
  {
    'armannikoyan/rusty',
    lazy = true,
    opts = {},
    config = function(_, opts)
      require('rusty').setup(opts)
    end,
  },
}
