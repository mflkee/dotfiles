-- Rust configuration is handled by rustaceanvim plugin
-- This file is kept for compatibility but rustaceanvim handles everything
local M = {}

function M.setup(capabilities)
  -- Rust configuration is handled by rustaceanvim, which should already be configured
  -- Just ensure rust-analyzer settings are applied if rustaceanvim is properly set up
  vim.g.rustaceanvim = vim.g.rustaceanvim or {}
  vim.g.rustaceanvim = {
    tools = {
      runnables = { use_telescope = true },
      inlay_hints = { auto = true },
    },
    server = {
      on_attach = function(client, bufnr)
        local opts = { buffer = bufnr }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<leader>f", function()
          vim.lsp.buf.format { async = true }
        end, opts)
      end,
      capabilities = capabilities,
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
