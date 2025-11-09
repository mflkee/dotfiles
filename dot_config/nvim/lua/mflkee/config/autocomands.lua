-- More organized autocommands with better grouping:

-- Create specific groups for better organization
local augroups = {
    general = vim.api.nvim_create_augroup("General", { clear = true }),
    terminal = vim.api.nvim_create_augroup("Terminal", { clear = true }),
    language = vim.api.nvim_create_augroup("LanguageSpecific", { clear = true }),
    sql = vim.api.nvim_create_augroup("SQL", { clear = true }),
    plantuml = vim.api.nvim_create_augroup("PlantUML", { clear = true }),
    format = vim.api.nvim_create_augroup("Format", { clear = true }),
}

-- General autocommands
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = augroups.general,
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Terminal autocommands
vim.api.nvim_create_autocmd("TermOpen", {
    desc = "Remove numbers in terminal",
    group = augroups.terminal,
    callback = function()
        vim.wo.number = false
        vim.wo.relativenumber = false
    end,
})

-- Keyboard layout switching
vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    group = augroups.general,
    callback = function()
        if vim.fn.executable("xkb-switch") == 1 then
            vim.system({ "xkb-switch", "-s", "us" }, { text = true }, function() end)
        end
    end,
})

-- Format on save for specific filetypes
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = {"*.cpp", "*.c", "*.h", "*.hpp"},
    group = augroups.format,
    callback = function()
        local ok, conform = pcall(require, "conform")
        if ok then
            conform.format({ async = true, lsp_fallback = true })
        end
    end,
})

-- Language-specific indentation settings
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "cpp", "c", "h", "hpp" },
    group = augroups.language,
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
        vim.opt_local.smartindent = false
        vim.opt_local.autoindent = true
        vim.opt_local.cinoptions = {
            ":0",
            "l1",
        }
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "lua" },
    group = augroups.language,
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
        vim.opt_local.smartindent = false
        vim.opt_local.autoindent = true
    end,
})

-- SQL-specific autocommands
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "sql", "mysql", "plsql", "pgsql", "psql" },
    group = augroups.sql,
    callback = function()
        vim.bo.omnifunc = "vim_dadbod_completion#omni"

        local ok, cmp = pcall(require, "cmp")
        if ok then
            cmp.setup.buffer({
                sources = cmp.config.sources({
                    { name = "vim_dadbod-completion" },
                }, {
                    { name = "buffer" },
                    { name = "path" },
                }),
            })
        end
    end,
})

-- PlantUML template
vim.api.nvim_create_autocmd("BufNewFile", {
    pattern = "*.puml",
    group = augroups.plantuml,
    callback = function()
        local lines = {
            "@startuml",
            "!include /home/mflkee/.config/plantuml/dracula.puml",
            "",
            "@enduml",
        }
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
    end,
})

-- Format options for specific file types
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "lua", "python", "rust", "cpp", "c" },
    group = augroups.language,
    callback = function()
        vim.opt_local.formatoptions:remove({ "c", "r", "o" })
    end,
})

-- SQL F7 mapping
vim.api.nvim_create_autocmd("FileType", {
    pattern = "sql",
    group = augroups.sql,
    callback = function()
        vim.keymap.set('n', '<F7>', 'vip<Plug>(DBUI_ExecuteQuery)', {
            buffer = true,
            desc = 'Execute SQL block with dbui',
            silent = true
        })

        vim.keymap.set('v', '<F7>', '<Plug>(DBUI_ExecuteQuery)', {
            buffer = true,
            desc = 'Execute selected SQL with dbui',
            silent = true
        })

        vim.keymap.set('i', '<F7>', '<Esc>vip<Plug>(DBUI_ExecuteQuery)', {
            buffer = true,
            desc = 'Execute SQL block with dbui',
            silent = true
        })
    end,
})