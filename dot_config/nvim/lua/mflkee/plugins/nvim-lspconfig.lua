return {
    -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    opts = {},
    dependencies = {
        -- Automatically install LSPs and related tools to stdpath for Neovim
        { "williamboman/mason.nvim", config = true },
        "williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        -- Useful status updates for LSP
        { "j-hui/fidget.nvim", opts = {} },
        -- Configure Lua LSP for Neovim
        { "folke/neodev.nvim", opts = {} },
        -- Autocompletion
        "hrsh7th/nvim-cmp",
    },
    config = function()
        -- Настраиваем neodev для поддержки Neovim API
        require("neodev").setup()

        -- Включаем отладку LSP
        vim.lsp.set_log_level("debug")

        -- Создаём автокоманды для LSP
        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
            callback = function(event)
                local map = function(keys, func, desc)
                    vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
                end

                -- Маппинги LSP
                map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
                map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
                map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
                map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")
                map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
                map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
                map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
                map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
                map("K", vim.lsp.buf.hover, "Hover Documentation")
                map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

                -- Подсветка символов
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if client and client.server_capabilities.documentHighlightProvider then
                    local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
                    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                        buffer = event.buf,
                        group = highlight_augroup,
                        callback = vim.lsp.buf.document_highlight,
                    })
                    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                        buffer = event.buf,
                        group = highlight_augroup,
                        callback = vim.lsp.buf.clear_references,
                    })
                end

                -- Inlay hints
                if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
                    map("<leader>th", function()
                        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
                    end, "[T]oggle Inlay [H]ints")
                end
            end,
        })

        vim.api.nvim_create_autocmd("LspDetach", {
            group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
            callback = function(event)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event.buf })
            end,
        })

        -- Настраиваем capabilities для LSP
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
        capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false

        -- Определяем серверы LSP
        local servers = {
            clangd = {
                cmd = {
                    "clangd",
                    "--background-index",
                    "--clang-tidy",
                    "--all-scopes-completion",
                    "--completion-style=detailed",
                    "--header-insertion=iwyu",
                    "--pch-storage=memory",
                },
                filetypes = { "c", "cpp", "objc", "objcpp" },
                root_dir = require("lspconfig.util").root_pattern("compile_commands.json", "compile_flags.txt", ".git"),
            },
            pyright = {},
            rust_analyzer = {},
            bashls = {},
            ruff = {},
            yamlls = {},
            taplo = {},
            lua_ls = {
                settings = {
                    Lua = {
                        completion = {
                            callSnippet = "Replace",
                        },
                        diagnostics = {
                            globals = { "vim" }, -- Распознаём vim как глобальную переменную
                            disable = { "missing-fields" },
                        },
                    },
                },
            },
        }

        -- Настраиваем Mason
        require("mason").setup()
        local ensure_installed = vim.tbl_keys(servers or {})
        vim.list_extend(ensure_installed, {
            "stylua",
            "clang-format",
            "clangd",
            "typescript-language-server",
            "css-lsp",
            "ast-grep",
            "ruff",
        })

        -- Настраиваем форматтеры через conform.nvim
        require("conform").setup({
            formatters_by_ft = {
                cpp = { "clang_format" },
                c = { "clang_format" },
                python = { "ruff" },
            },
            format_on_save = false,
        })

        require("mason-tool-installer").setup({ ensure_installed = ensure_installed })
        -- в самом верху вашего config-файла, до require("mason-lspconfig").setup
        --
        require("neodev").setup({
          library = { plugins = true, types = true },  -- подтягивает runtime API, плагины, типы
          setup_jsonls = false,                       -- если вы не юзаете jsonls через neodev
          override = function(root_dir, library)      -- дополнительные папки
            library["/path/to/доп.модулей"] = true
          end,
        })

        -- Автоматическая настройка серверов через mason-lspconfig
        require("mason-lspconfig").setup({
            handlers = {
                ["rust_analyzer"] = function() end,
                function(server_name)
                    local server = servers[server_name] or {}
                    server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
                    require("lspconfig")[server_name].setup(server)
                end,
            }
        })
    end,
}
