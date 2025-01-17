return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        size = 10,
        open_mapping = [[<A-t>]], -- Измените на желаемое сочетание клавиш
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = '1',
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = 'horizontal',
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = 'curved',
          winblend = 3,
          highlights = {
            border = 'Normal',
            background = 'Normal',
          },
        },
      }
    end,
  },
}
