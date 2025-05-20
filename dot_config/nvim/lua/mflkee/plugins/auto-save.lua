return {
  {
    "Pocco81/auto-save.nvim",
    config = function()
      require("auto-save").setup({
        enabled = true,
        trigger_events = { "InsertLeave", "TextChanged", "TextChangedI" },
        debounce_delay = 250, -- Обязательно добавьте это
        condition = function(buf)
          return not vim.fn.expand("%"):match("NvimTree") -- Игнорировать NvimTree
        end,
        write_all_buffers = false,
        noautocmd = false,
        silent = true, -- Отключить сообщения
      })
    end,
  }
}
