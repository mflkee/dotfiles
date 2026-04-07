return {
  {
    "Pocco81/auto-save.nvim",
    config = function()
      require("auto-save").setup({
        enabled = #vim.api.nvim_list_uis() > 0,
        execution_message = {
          message = "",
          cleaning_interval = 0,
        },
        trigger_events = { "InsertLeave", "TextChanged", "TextChangedI" },
        debounce_delay = 250,
        condition = function(buf)
          local fn = vim.fn

          if #vim.api.nvim_list_uis() == 0 then
            return false
          end
          
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

          if fn.getbufvar(buf, "&modifiable") ~= 1 or fn.getbufvar(buf, "&readonly") == 1 then
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
