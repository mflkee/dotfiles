-- Basic keymaps and autocmds.
-- LazyVim-style leader descriptions: `[R]un in [T]erminal` → <leader>rt, etc.

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- [[ Diagnostic Config & Keymaps ]]
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Text shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float {
        bufnr = bufnr,
        scope = 'cursor',
        focus = false,
      }
    end,
  },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is easier to
-- discover than the default <C-\><C-n>.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- [[ Terminal / Code runner ]]
local terminal_buf = nil
local terminal_win = nil
local terminal_job_id = nil

local function open_terminal()
  -- Terminal window already exists
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    vim.api.nvim_set_current_win(terminal_win)
    return
  end

  -- Create bottom split
  vim.cmd 'botright 12split'

  terminal_win = vim.api.nvim_get_current_win()

  -- Reuse existing terminal buffer
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    vim.api.nvim_win_set_buf(terminal_win, terminal_buf)
  else
    vim.cmd 'terminal'
    terminal_buf = vim.api.nvim_get_current_buf()
    terminal_job_id = vim.b.terminal_job_id
  end
end

local function run_in_terminal(command)
  open_terminal()

  if not terminal_job_id then
    vim.notify('Terminal job is not available', vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_chan_send(terminal_job_id, command .. '\n')
  vim.cmd 'startinsert'
end

local function cargo_manifest_dir()
  local file = vim.fn.expand '%:p'
  local start = file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd()
  local manifest = vim.fs.find('Cargo.toml', {
    upward = true,
    path = start,
    type = 'file',
    limit = 1,
  })[1]

  if not manifest then
    vim.notify('Cargo.toml not found above the current file', vim.log.levels.ERROR)
    return nil
  end
  return vim.fs.dirname(manifest)
end

local function run_cargo(subcommand)
  local manifest_dir = cargo_manifest_dir()
  if not manifest_dir then return end
  run_in_terminal(('cd %s && cargo %s'):format(vim.fn.shellescape(manifest_dir), subcommand))
end

local function run_current_file()
  local ft = vim.bo.filetype
  local file = vim.fn.expand '%:p'
  local filename = vim.fn.shellescape(file)

  local commands = {
    python = 'python3 ' .. filename,
    bash = 'bash ' .. filename,
    sh = 'bash ' .. filename,
    javascript = 'node ' .. filename,
    typescript = 'npx tsx ' .. filename,
    lua = 'lua ' .. filename,
    ruby = 'ruby ' .. filename,
    perl = 'perl ' .. filename,

    c = 'gcc ' .. filename .. ' -o /tmp/nvim_run && /tmp/nvim_run',
    cpp = 'g++ ' .. filename .. ' -o /tmp/nvim_run && /tmp/nvim_run',
  }

  -- Rust projects use Cargo from the manifest directory, not from an
  -- arbitrary Neovim working directory.
  if ft == 'rust' then
    run_cargo 'run'
    return
  end

  local command = commands[ft]

  if not command then
    vim.notify('No runner configured for filetype: ' .. ft, vim.log.levels.WARN)
    return
  end

  run_in_terminal(command)
end

-- Run current file
vim.keymap.set('n', '<leader>rt', run_current_file, {
  desc = '[R]un in [T]erminal',
})

local cargo_mappings = {
  { '<leader>cb', 'build', '[C]argo [B]uild' },
  { '<leader>cc', 'check --all-targets', '[C]argo [C]heck all targets' },
  { '<leader>ct', 'test', '[C]argo [T]est' },
  { '<leader>cl', 'clippy --all-targets -- -D warnings', '[C]argo [C]lippy (deny warnings)' },
  { '<leader>cr', 'run', '[C]argo [R]un' },
  { '<leader>cR', 'run --release', '[C]argo [R]un release' },
}
for _, mapping in ipairs(cargo_mappings) do
  vim.keymap.set('n', mapping[1], function() run_cargo(mapping[2]) end, { desc = mapping[3] })
end

-- Debug
vim.keymap.set('n', '<leader>rd', function() require('dap').continue() end, {
  desc = '[R]un [D]ebugger',
})

local function toggle_terminal()
  -- Terminal is already open → close window
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    vim.api.nvim_win_close(terminal_win, true)
    terminal_win = nil
    return
  end

  open_terminal()
  vim.cmd 'startinsert'
end

vim.keymap.set('n', '<leader>tt', toggle_terminal, {
  desc = '[T]oggle [T]erminal',
})

-- Keybinds to make split navigation easier (CTRL+<hjkl>)
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Basic Autocommands ]]

-- Highlight when yanking (copying) text (try `yap` in normal mode)
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})
