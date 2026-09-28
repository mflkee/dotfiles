-- Snacks.nvim (folke, 2025): picker, notifier, dashboard, indent, image,
-- scratch, terminal, zen и др. Основной пикер вместо Telescope.
-- Telescope остаётся только ради vim.ui.select (см. plugins/search.lua).
local gh = require('mflkee.util').gh

vim.pack.add { gh 'folke/snacks.nvim' }

-- Встроенная секция `startup` дашборда вызывает `require("lazy.stats")`, а она
-- существует только под lazy.nvim. Здесь плагины ставятся нативным `vim.pack`,
-- поэтому заменяем секцию на эквивалент через `vim.pack.get()` + свой таймер
-- старта (см. init.lua). Регистрируем сразу после setup — дашборд Snacks
-- поднимается на UIEnter, то есть уже после загрузки init.lua.
local function startup_section()
  local loaded = 0
  for _ in pairs(vim.pack.get() or {}) do
    loaded = loaded + 1
  end
  local started = tonumber(vim.g.nvim_start_hrtime) or vim.uv.hrtime()
  local ms = math.floor((vim.uv.hrtime() - started) / 1e4 + 0.5) / 100
  return {
    align = 'center',
    text = {
      { '⚡ Neovim loaded ', hl = 'footer' },
      { loaded .. ' plugins in ', hl = 'special' },
      { ms .. 'ms', hl = 'special' },
    },
  }
end

require('snacks').setup {
  bigfile = { enabled = true },
  dashboard = { enabled = true },
  image = { enabled = true }, -- ghostty поддерживает kitty-graphics протокол
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true, timeout = 4000 },
  picker = { enabled = true },
  quickfile = { enabled = true },
  scratch = { enabled = true },
  scroll = { enabled = true },
  terminal = { enabled = true },
  words = { enabled = true },
  zen = { enabled = true },
}

Snacks.dashboard.sections.startup = startup_section

-- Дополнительные маппинги Snacks (основные пикеры — в plugins/search.lua)
vim.keymap.set('n', '<leader>.', function() Snacks.scratch() end, { desc = 'Toggle Scratch Buffer' })
vim.keymap.set('n', '<C-/>', function() Snacks.terminal() end, { desc = 'Toggle Terminal' })
vim.keymap.set('n', '<leader>z', function() Snacks.zen() end, { desc = 'Toggle Zen Mode' })
vim.keymap.set('n', '<leader>n', function() Snacks.notifier.show_history() end, { desc = 'Notification History' })

-- Git: lazygit во флоате (тема автоматически под цветовую схему) + GitHub browse
vim.keymap.set('n', '<leader>gg', function() Snacks.lazygit() end, { desc = 'Lazygit (float)' })
vim.keymap.set({ 'n', 'v' }, '<leader>gB', function() Snacks.gitbrowse() end, { desc = 'Git Browse (GitHub)' })
