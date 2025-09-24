return {
  {
    "Pocco81/auto-save.nvim",
    config = function()
      require("auto-save").setup({
        enabled = true,
        trigger_events = { "InsertLeave", "TextChanged", "TextChangedI" },
        debounce_delay = 250,
        condition = function(buf)
          local fn = vim.fn
          
          -- Игнорировать NvimTree
          if fn.expand("%"):match("NvimTree") then
            return false
          end
          
          -- Игнорировать SQL файлы
          if vim.bo[buf].filetype:match("sql") then
            return false
          end
          
          -- Игнорировать временные файлы (простая проверка)
          local buftype = fn.getbufvar(buf, "&buftype")
          if buftype ~= "" and buftype ~= "acwrite" then
            return false
          end
          
          return true
        end,
        write_all_buffers = false,
        noautocmd = false,
        silent = true,
      })
    end,
  }
}
