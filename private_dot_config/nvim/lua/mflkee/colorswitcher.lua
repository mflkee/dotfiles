local M = {}

local themes = {
  { id = 'catppuccin', label = 'Catppuccin Mocha', colorscheme = 'catppuccin' },
  { id = 'tokyonight', label = 'Tokyo Night', colorscheme = 'tokyonight-night' },
  { id = 'dracula', label = 'Dracula', colorscheme = 'dracula' },
  {
    id = 'gruvbox',
    label = 'Gruvbox Material',
    colorscheme = 'gruvbox-material',
    before = function()
      vim.g.gruvbox_material_background = 'medium'
      vim.g.gruvbox_material_foreground = 'original'
    end,
  },
  { id = 'kanagawa', label = 'Kanagawa Dragon', colorscheme = 'kanagawa' },
  { id = 'monokai', label = 'Monokai Pro', colorscheme = 'monokai-pro' },
  { id = 'moonfly', label = 'Moonfly', colorscheme = 'moonfly' },
  { id = 'nightfox', label = 'Duskfox', colorscheme = 'duskfox' },
  { id = 'rose-pine', label = 'Rose Pine', colorscheme = 'rose-pine' },
  {
    id = 'hardhacker',
    label = 'Hardhacker',
    colorscheme = 'hardhacker',
    before = function()
      vim.g.hardhacker_hide_tilde = 1
      vim.g.hardhacker_keyword_italic = 1
      vim.g.hardhacker_custom_highlights = vim.g.hardhacker_custom_highlights or {}
    end,
  },
  {
    id = 'sonokai',
    label = 'Sonokai',
    colorscheme = 'sonokai',
    before = function()
      vim.g.sonokai_style = vim.g.sonokai_style or 'andromeda'
      vim.g.sonokai_enable_italic = 1
      vim.g.sonokai_diagnostic_text_highlight = 1
    end,
  },
}

local current_index = 1

local function find_index(id)
  for i, theme in ipairs(themes) do
    if theme.id == id then
      return i
    end
  end
end

local function apply(theme, opts)
  opts = opts or {}
  if not theme then
    return false
  end

  if theme.before then
    theme.before()
  end

  local ok, err = pcall(vim.cmd.colorscheme, theme.colorscheme)
  if not ok then
    vim.notify('Theme failed: ' .. theme.colorscheme .. ' (' .. err .. ')', vim.log.levels.WARN)
    return false
  end

  current_index = find_index(theme.id) or current_index
  if not opts.silent then
    vim.notify('Colorscheme: ' .. (theme.label or theme.colorscheme), vim.log.levels.INFO)
  end
  return true
end

local function cycle(delta)
  local total = #themes
  local idx = current_index
  for _ = 1, total do
    idx = ((idx - 1 + delta) % total) + 1
    if apply(themes[idx]) then
      break
    end
  end
end

function M.set(id)
  local idx = find_index(id)
  if idx then
    return apply(themes[idx])
  end
  vim.notify('Unknown theme: ' .. id, vim.log.levels.WARN)
  return false
end

function M.next()
  cycle(1)
end

function M.prev()
  cycle(-1)
end

function M.setup(opts)
  opts = opts or {}
  if opts.themes then
    themes = opts.themes
  end
  if opts.default then
    current_index = find_index(opts.default) or current_index
  end

  apply(themes[current_index], { silent = true })

  vim.keymap.set('n', '<leader>tn', M.next, { desc = 'Theme next' })
  vim.keymap.set('n', '<leader>tp', M.prev, { desc = 'Theme previous' })
  vim.api.nvim_create_user_command('ThemeNext', M.next, { desc = 'Next colorscheme' })
  vim.api.nvim_create_user_command('ThemePrev', M.prev, { desc = 'Previous colorscheme' })
  vim.api.nvim_create_user_command('ThemeSet', function(cmd)
    M.set(cmd.args)
  end, { desc = 'Set colorscheme by id', nargs = 1, complete = function()
    return vim.tbl_map(function(theme)
      return theme.id
    end, themes)
  end })
end

return M
