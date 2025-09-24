-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands` Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("TermOpen", {
	desc = "remove numbers line in terminal",
	group = vim.api.nvim_create_augroup("kickstart-term", { clear = true }),
	callback = function()
		vim.wo.number = false
	end,
})

-- Переключение на английскую раскладку при выходе из режима вставки
vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    callback = function()
        if vim.fn.executable("xkb-switch") == 1 then
            vim.system({ "xkb-switch", "-s", "us" }, { text = true }, function() end)
        end
    end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.cpp",
	callback = function()
		require("conform").format({ async = true, lsp_fallback = true })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "cpp", "c", "h", "hpp" }, -- Файлы C++
    callback = function()
		vim.opt_local.tabstop = 2 -- Размер табуляции
		vim.opt_local.shiftwidth = 2 -- Размер отступа
		vim.opt_local.expandtab = true -- Преобразовывать Tab в пробелы
		vim.opt_local.smartindent = false -- Отключить умные отступы
		vim.opt_local.autoindent = false -- Отключить автоиндентацию
		vim.opt_local.cinoptions = {
			":0", -- Не добавлять дополнительные отступы после `{`
			"l1", -- Уровень отступа для `{` и `}`
		}
    end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "lua" }, -- Файлы Lua
	callback = function()
		vim.opt_local.tabstop = 2 -- Размер табуляции
		vim.opt_local.shiftwidth = 2 -- Размер отступа
		vim.opt_local.expandtab = true -- Преобразовывать Tab в пробелы
		vim.opt_local.smartindent = false -- Отключить умные отступы
		vim.opt_local.autoindent = false -- Отключить автоиндентацию
    end,
})

-- Автовключение vim-dadbod-completion + nvim-cmp в SQL буферах
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "sql", "mysql", "plsql", "pgsql", "psql" },
  group = vim.api.nvim_create_augroup("dadbod_completion_sql", { clear = true }),
  callback = function()
    -- omnifunc для built-in completion и источника cmp-omni
    vim.bo.omnifunc = "vim_dadbod_completion#omni"

    -- nvim-cmp: источник vim-dadbod-completion для текущего буфера
    local ok, cmp = pcall(require, "cmp")
    if ok then
      cmp.setup.buffer({
        sources = cmp.config.sources({
          { name = "vim-dadbod-completion" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end
  end,
})



vim.api.nvim_create_autocmd("BufNewFile", {
	pattern = "*.puml",
	callback = function()
		local lines = {
			"@startuml",
			"!include /home/mflkee/.config/plantuml/dracula.puml",
			"",
			"@enduml",
		}
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- курсор на пустую строку
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	callback = function()
		vim.opt_local.formatoptions:remove({ "c", "r", "o" })
	end,
})

-- Автокоманда для выполнения SQL-запроса через F7
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sql",
  group = vim.api.nvim_create_augroup("sql_f7_mapping", { clear = true }),
  callback = function()
    -- Нормальный режим: выделяет блок и выполняет запрос
    vim.keymap.set('n', '<F7>', 'vip<Plug>(DBUI_ExecuteQuery)', { 
      buffer = true, 
      desc = 'Execute SQL block with dbui',
      silent = true
    })
    
    -- Визуальный режим: выполняет выделенное
    vim.keymap.set('v', '<F7>', '<Plug>(DBUI_ExecuteQuery)', { 
      buffer = true, 
      desc = 'Execute selected SQL with dbui',
      silent = true
    })
    
    -- Режим вставки: выходит в нормальный режим и выполняет блок
    vim.keymap.set('i', '<F7>', '<Esc>vip<Plug>(DBUI_ExecuteQuery)', { 
      buffer = true, 
      desc = 'Execute SQL block with dbui',
      silent = true
    })
  end,
})
