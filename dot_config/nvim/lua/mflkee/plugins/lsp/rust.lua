local M = {}

function M.setup(capabilities)
  if vim.fn.executable("cargo") == 0 then
    vim.notify(
      "Cargo не найден! Некоторые функции Rust недоступны",
      vim.log.levels.WARN
    )
  end

  -- Только настройка rustaceanvim, без дублирования LSP
  vim.g.rustaceanvim = {
    tools = {
      runnables = { use_telescope = true },
      inlay_hints = { auto = true },
    },
    server = {
      on_attach = function(_, bufnr)
        local opts = { buffer = bufnr }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      end,
      capabilities = capabilities,
      settings = {
        ["rust-analyzer"] = {
          cargo = { allFeatures = true },
          check = { command = "clippy" },
        },
      },
    },
    dap = {
      adapter = {
        type = "server",
        port = "${port}",
        executable = {
          command = "codelldb",
          args = { "--port", "${port}" },
          detached = false,
        },
      },
    },
  }
end

return M
