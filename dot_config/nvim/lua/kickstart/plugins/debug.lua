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

-- ============================================================
-- KEYMAPS
-- ============================================================

-- Breakpoints
vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, {
  desc = 'Debug: Toggle Breakpoint',
})

vim.keymap.set('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, {
  desc = 'Debug: Conditional Breakpoint',
})

-- Debug control
vim.keymap.set('n', '<leader>dd', dap.continue, {
  desc = '[D]ebug [D]ebug / Continue',
})

vim.keymap.set('n', '<leader>di', dap.step_into, {
  desc = '[D]ebug Step [I]nto',
})

vim.keymap.set('n', '<leader>do', dap.step_over, {
  desc = '[D]ebug Step [O]ver',
})

vim.keymap.set('n', '<leader>du', dap.step_out, {
  desc = '[D]ebug Step O[u]t',
})

vim.keymap.set('n', '<leader>dt', dap.terminate, {
  desc = '[D]ebug [T]erminate',
})

vim.keymap.set('n', '<leader>dU', dapui.toggle, {
  desc = '[D]ebug Toggle [U]I',
})

vim.keymap.set('n', '<leader>dr', dap.restart, {
  desc = '[D]ebug [R]estart',
})
-- ============================================================
-- MASON DAP
-- ============================================================

-- debugpy и codelldb устанавливаются через mason-tool-installer
-- в основном init.lua.
--
-- mason-nvim-dap здесь нужен только для интеграции с nvim-dap.
require('mason-nvim-dap').setup {
  ensure_installed = {},
  automatic_installation = false,
  handlers = {},
}

-- ============================================================
-- DAP UI
-- ============================================================

---@type dapui.Config
local dapui_config = {
  wrap = false,

  icons = {
    expanded = '▾',
    collapsed = '▸',
    current_frame = '*',
  },

  mappings = {
    expand = { '<CR>', '<2-LeftMouse>' },
    open = 'o',
    remove = 'd',
    edit = 'e',
    repl = 'r',
    toggle = 't',
  },

  element_mappings = {},

  expand_lines = true,
  force_buffers = true,

  layouts = {
    {
      elements = {
        { id = 'scopes', size = 0.25 },
        { id = 'breakpoints', size = 0.25 },
        { id = 'stacks', size = 0.25 },
        { id = 'watches', size = 0.25 },
      },
      size = 40,
      position = 'left',
    },

    {
      elements = {
        { id = 'repl', size = 0.5 },
        { id = 'console', size = 0.5 },
      },
      size = 10,
      position = 'bottom',
    },
  },

  floating = {
    max_height = nil,
    max_width = nil,
    border = 'rounded',

    mappings = {
      close = { 'q', '<Esc>' },
    },
  },

  controls = {
    enabled = true,
    element = 'repl',

    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
    },
  },

  render = {
    max_type_length = nil,
    max_value_lines = 100,
    indent = 1,
  },
}

dapui.setup(dapui_config)

-- Automatically open/close DAP UI.
dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end

dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end

dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

-- ============================================================
-- PYTHON
-- ============================================================

dap.adapters.python = {
  type = 'executable',
  command = vim.fn.stdpath 'data' .. '/mason/bin/debugpy-adapter',
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

-- ============================================================
-- RUST
-- ============================================================

dap.adapters.codelldb = {
  type = 'executable',
  command = vim.fn.stdpath 'data' .. '/mason/bin/codelldb',
}

local rust_info_cache

local function normalize_path(path) return vim.fs.normalize(vim.fn.fnamemodify(path or vim.fn.getcwd(), ':p')) end

local function rust_project_info()
  local file = vim.api.nvim_buf_get_name(0)
  local cache_key = file ~= '' and normalize_path(file) or vim.fn.getcwd()
  if rust_info_cache and rust_info_cache.key == cache_key then return rust_info_cache.value end

  if vim.fn.exepath 'cargo' == '' then error('cargo is not installed or is not in PATH', 0) end

  local start = file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd()
  local manifest = vim.fs.find('Cargo.toml', {
    upward = true,
    path = start,
    type = 'file',
    limit = 1,
  })[1]
  if not manifest then error('Cargo.toml not found above the current Rust file', 0) end
  manifest = normalize_path(manifest)

  local result = vim
    .system({
      'cargo',
      'metadata',
      '--no-deps',
      '--format-version',
      '1',
      '--manifest-path',
      manifest,
    }, { cwd = vim.fs.dirname(manifest), text = true })
    :wait()

  if result.code ~= 0 then error(('cargo metadata failed:\n%s'):format(result.stderr or result.stdout or 'unknown error'), 0) end

  local ok, metadata = pcall(vim.json.decode, result.stdout)
  if not ok then error('cargo metadata returned invalid JSON', 0) end

  local package
  for _, candidate in ipairs(metadata.packages or {}) do
    if normalize_path(candidate.manifest_path) == manifest then
      package = candidate
      break
    end
  end

  if not package and #(metadata.packages or {}) == 1 then package = metadata.packages[1] end
  if not package then error('Cargo package for the current file was not found', 0) end

  local executables = {}
  for _, target in ipairs(package.targets or {}) do
    local kind = target.kind or {}
    if vim.tbl_contains(kind, 'bin') or vim.tbl_contains(kind, 'example') then table.insert(executables, target) end
  end
  if #executables == 0 then error(('Cargo package %q has no binary or example target to debug'):format(package.name), 0) end

  local value = {
    manifest = manifest,
    package = package,
    executables = executables,
    target_directory = normalize_path(metadata.target_directory or 'target'),
    workspace_root = normalize_path(metadata.workspace_root or vim.fs.dirname(manifest)),
  }
  rust_info_cache = { key = cache_key, value = value }
  return value
end

local function choose_rust_executable(info)
  local current_file = normalize_path(vim.api.nvim_buf_get_name(0))
  for _, target in ipairs(info.executables) do
    if target.src_path and normalize_path(target.src_path) == current_file then return target end
  end

  if #info.executables == 1 then return info.executables[1] end

  local labels = vim.tbl_map(
    function(target) return ('%s [%s] — %s'):format(target.name, target.kind[1], target.src_path or '<unknown source>') end,
    info.executables
  )
  local choice = vim.fn.inputlist(('Debug executable in %s:'):format(info.package.name), labels)
  if choice == 0 then error('Rust debug launch cancelled', 0) end
  return info.executables[choice]
end

local function rust_debug_program()
  local info = rust_project_info()
  local target = choose_rust_executable(info)
  local is_example = vim.tbl_contains(target.kind, 'example')
  local selector = is_example and '--example' or '--bin'
  local output_dir = vim.fs.joinpath(info.target_directory, 'debug')
  if is_example then output_dir = vim.fs.joinpath(output_dir, 'examples') end
  local program = vim.fs.joinpath(output_dir, target.name)

  vim.notify(('Building Rust %s %s for debugging…'):format(is_example and 'example' or 'binary', target.name), vim.log.levels.INFO)
  local result = vim
    .system({
      'cargo',
      'build',
      '--manifest-path',
      info.manifest,
      selector,
      target.name,
    }, { cwd = info.workspace_root, text = true })
    :wait()

  if result.code ~= 0 then error(('cargo build %s %s failed:\n%s'):format(selector, target.name, result.stderr or result.stdout or 'unknown error'), 0) end

  return program
end

dap.configurations.rust = {
  {
    name = 'Rust: Debug current Cargo executable',
    type = 'codelldb',
    request = 'launch',
    program = rust_debug_program,
    cwd = function() return rust_project_info().workspace_root end,
    stopOnEntry = false,
  },
}
