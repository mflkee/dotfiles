-- Search & navigation: основной пикер — Snacks, Telescope остаётся только для
-- vim.ui.select (extensions.ui-select). `Snacks.picker.*`, см. plugins/snacks.lua.
local gh = require('mflkee.util').gh

---@type (string|vim.pack.Spec)[]
local telescope_plugins = {
  gh 'nvim-lua/plenary.nvim',
  gh 'nvim-telescope/telescope.nvim',
  gh 'nvim-telescope/telescope-ui-select.nvim',
}
vim.pack.add(telescope_plugins)

require('telescope').setup {
  extensions = {
    ['ui-select'] = { require('telescope.themes').get_dropdown() },
  },
}
pcall(require('telescope').load_extension, 'ui-select')

-- Основные пикеры (Snacks; см. какие ещё бывают: <leader>sh → Help)
vim.keymap.set('n', '<leader>sh', function() Snacks.picker.help() end, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', function() Snacks.picker.keymaps() end, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', function() Snacks.picker.files() end, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ss', function() Snacks.picker.command_history() end, { desc = '[S]earch Command History' })
vim.keymap.set({ 'n', 'v' }, '<leader>sw', function() Snacks.picker.grep_word() end, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', function() Snacks.picker.grep() end, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', function() Snacks.picker.diagnostics() end, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', function() Snacks.picker.resume() end, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', function() Snacks.picker.recent() end, { desc = '[S]earch Recent Files' })
vim.keymap.set('n', '<leader>sc', function() Snacks.picker.commands() end, { desc = '[S]earch [C]ommands' })
vim.keymap.set('n', '<leader><leader>', function() Snacks.picker.buffers() end, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>sn', function() Snacks.picker.files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
vim.keymap.set('n', '<leader>s/', function() Snacks.picker.grep_buffers() end, { desc = '[S]earch [/] in Open Files' })
vim.keymap.set('n', '<leader>/', function() Snacks.picker.lines() end, { desc = '[/] Fuzzily search in current buffer' })

-- LSP-пикеры (Snacks) при аттаче LSP
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('snacks-lsp-attach', { clear = true }),
  callback = function(event)
    local buf = event.buf
    vim.keymap.set('n', 'grr', function() Snacks.picker.lsp_references() end, { buffer = buf, desc = '[G]oto [R]eferences' })
    vim.keymap.set('n', 'gri', function() Snacks.picker.lsp_implementations() end, { buffer = buf, desc = '[G]oto [I]mplementation' })
    vim.keymap.set('n', 'grd', function() Snacks.picker.lsp_definitions() end, { buffer = buf, desc = '[G]oto [D]efinition' })
    vim.keymap.set('n', 'gO', function() Snacks.picker.lsp_symbols() end, { buffer = buf, desc = 'Open Document Symbols' })
    vim.keymap.set('n', 'gW', function() Snacks.picker.lsp_workspace_symbols() end, { buffer = buf, desc = 'Open Workspace Symbols' })
    vim.keymap.set('n', 'grt', function() Snacks.picker.lsp_type_definitions() end, { buffer = buf, desc = '[G]oto [T]ype Definition' })
  end,
})

-- Open whatever is under the cursor:
--   markdown/quarto: [text](notes/note.md), [[note]], <https://…>, bare URL
--   code: "./example.rs", include_str!("…"), mod example;, plain file names
-- URLs open in Zen Browser (see `g:mflkee_browser`), paths and notes as buffers.
vim.keymap.set('n', '<leader>o', function() require('mflkee.config.functions').open_target_under_cursor() end, { desc = '[O]pen path/URL under cursor' })
