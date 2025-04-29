return {
  { -- Autoformat with Conform
    "stevearc/conform.nvim",
    lazy = false,
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_fallback = true, stop_after_first = true })
        end,
        mode = { "n", "v" },
        desc = "[F]ormat buffer",
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = true,

      -- Specify which formatters run per filetype (flat list; stop after first success)
      formatters_by_ft = {
        lua        = { "stylua", stop_after_first = true },
        python     = { "ruff_format", stop_after_first = true },
        rust       = { "rustfmt", stop_after_first = true },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        c          = { "clang_format", stop_after_first = true },
        cpp        = { "clang_format", stop_after_first = true },
        go         = { "gofmt", "goimports", stop_after_first = true },
        plantuml  = {},
      },

      -- Custom formatter definitions (stdin and filename handling)
      formatters = {
        stylua = {
          command = "stylua",
          args    = { "--stdin-filepath", vim.api.nvim_buf_get_name(0), "-" },
          stdin   = true,
        },
        ruff = {
          command = "ruff",
          args = { "format", "--stdin-filename", vim.api.nvim_buf_get_name(0), "-" },
          stdin = true,
        },
        rustfmt = {
          command = "rustfmt",
          args    = { "--emit", "stdout", "--edition", "2021" },
          stdin   = true,
        },
        prettierd = {
          command = "prettierd",
          args    = { "--stdin-filepath", vim.api.nvim_buf_get_name(0) },
          stdin   = true,
        },
        prettier = {
          command = "prettier",
          args    = { "--stdin-filepath", vim.api.nvim_buf_get_name(0) },
          stdin   = true,
        },
        clang_format = {
          command = "clang-format",
          args    = { "--assume-filename", vim.api.nvim_buf_get_name(0) },
          stdin   = true,
        },
        gofmt = {
          command = "gofmt",
          args    = {},
          stdin   = true,
        },
        goimports = {
          command = "goimports",
          args    = {},
          stdin   = true,
        },
      },
    },
  },
}
