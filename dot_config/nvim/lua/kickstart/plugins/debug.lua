-- Debugging: Python + Rust

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}

local dap = require 'dap'
local dapui = require 'dapui'

-- Debugging keymaps
vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Start / Continue' })
vim.keymap.set('n', '<F1>', dap.step_into, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', dap.step_over, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', dap.step_out, { desc = 'Debug: Step Out' })

vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, {
  desc = 'Debug: Toggle Breakpoint',
})

vim.keymap.set('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, {
  desc = 'Debug: Conditional Breakpoint',
})

vim.keymap.set('n', '<F7>', dapui.toggle, {
  desc = 'Debug: Toggle UI',
})

-- Mason DAP
require('mason-nvim-dap').setup {
  automatic_installation = true,

  handlers = {},

  ensure_installed = {
    'debugpy',
    'codelldb',
  },
}

-- DAP UI
dapui.setup {
  icons = {
    expanded = '▾',
    collapsed = '▸',
    current_frame = '*',
  },

  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Open DAP UI when debugging starts
dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end

-- Close DAP UI when debugging ends
dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end

dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

-- Python / debugpy
dap.adapters.python = {
  type = 'executable',
  command = 'debugpy-adapter',
}

dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = 'Python: Current File',
    program = '${file}',
    pythonPath = function()
      local venv = os.getenv 'VIRTUAL_ENV'

      if venv then return venv .. '/bin/python' end

      return vim.fn.exepath 'python3'
    end,
  },
}

-- Rust / C / C++ / codelldb
dap.adapters.codelldb = {
  type = 'executable',
  command = vim.fn.exepath 'codelldb',
}

dap.configurations.rust = {
  {
    name = 'Rust: Debug',
    type = 'codelldb',
    request = 'launch',
    program = function() return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file') end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
}
