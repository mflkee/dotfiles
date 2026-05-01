-- Rust configuration is handled by rustaceanvim plugin
-- This file is kept for compatibility but rustaceanvim handles everything
local M = {}

local function resolve_rust_analyzer_cmd()
  local system_cmd = '/usr/bin/rust-analyzer'
  if vim.fn.executable(system_cmd) == 1 then
    return { system_cmd }
  end

  local exepath = vim.fn.exepath('rust-analyzer')
  if exepath ~= '' and not exepath:find('/mason/', 1, true) then
    return { exepath }
  end

  local candidates = {
    vim.fn.stdpath('data') .. '/mason/bin/rust-analyzer',
    vim.fn.expand('~/.cargo/bin/rust-analyzer'),
  }

  for _, cmd in ipairs(candidates) do
    if vim.fn.executable(cmd) == 1 then
      return { cmd }
    end
  end

  return nil
end

function M.setup(capabilities)
  -- Rust configuration is handled by rustaceanvim, which should already be configured
  -- Just ensure rust-analyzer settings are applied if rustaceanvim is properly set up
  local rust_analyzer_cmd = resolve_rust_analyzer_cmd()
  local existing = vim.g.rustaceanvim or {}

  vim.g.rustaceanvim = vim.tbl_deep_extend("force", existing, {
    tools = {
      runnables = { use_telescope = true },
      inlay_hints = { auto = true },
    },
    server = {
      cmd = rust_analyzer_cmd,
      on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
        vim.keymap.set("n", "<leader>f", function()
          require("conform").format({ async = true, lsp_fallback = true, stop_after_first = true })
        end, opts)
      end,
      capabilities = capabilities,
      default_settings = {
        ['rust-analyzer'] = {
          cargo = {
            allFeatures = true,
            buildScripts = {
              enable = true,
            },
          },
          procMacro = {
            enable = true,
          },
          check = {
            command = 'clippy',
          },
          completion = {
            autoimport = {
              enable = true,
            },
            autoself = {
              enable = true,
            },
            callable = {
              snippets = 'fill_arguments',
            },
            fullFunctionSignatures = {
              enable = true,
            },
            postfix = {
              enable = true,
            },
          },
          diagnostics = {
            experimental = {
              enable = true,
            },
          },
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
  })
end

return M
