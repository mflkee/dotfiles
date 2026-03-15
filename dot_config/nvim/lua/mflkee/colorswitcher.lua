local M = {}

local themes = {
  { id = 'aura-dark', label = 'Aura Dark', colorscheme = 'aura-dark' },
  { id = 'aura-dark-soft-text', label = 'Aura Dark Soft Text', colorscheme = 'aura-dark-soft-text' },
  { id = 'aura-soft-dark', label = 'Aura Soft Dark', colorscheme = 'aura-soft-dark' },
  {
    id = 'aura-soft-dark-soft-text',
    label = 'Aura Soft Dark Soft Text',
    colorscheme = 'aura-soft-dark-soft-text',
  },
  { id = 'catppuccin', label = 'Catppuccin Mocha', colorscheme = 'catppuccin' },
  { id = 'tokyodark', label = 'Tokyo Dark', colorscheme = 'tokyodark' },
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
  { id = 'oxocarbon', label = 'Oxocarbon', colorscheme = 'oxocarbon' },
  { id = 'rose-pine', label = 'Rose Pine', colorscheme = 'rose-pine' },
  { id = 'rusty', label = 'Rusty', colorscheme = 'rusty' },
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
local state_file = vim.fn.stdpath('state') .. '/colorscheme.txt'
local theme_ids_by_colorscheme = {}
local find_index

local function load_saved_theme()
  if vim.fn.filereadable(state_file) == 0 then
    return nil
  end

  local lines = vim.fn.readfile(state_file)
  local id = vim.trim(lines[1] or '')
  if id == '' then
    return nil
  end

  return id
end

local function save_theme(theme)
  if not theme or not theme.id then
    return
  end

  local state_dir = vim.fn.stdpath('state')
  if vim.fn.isdirectory(state_dir) == 0 then
    vim.fn.mkdir(state_dir, 'p')
  end

  local ok, err = pcall(vim.fn.writefile, { theme.id }, state_file)
  if not ok then
    vim.notify('Failed to save theme: ' .. tostring(err), vim.log.levels.WARN)
  end
end

local function rebuild_theme_lookup()
  theme_ids_by_colorscheme = {}
  for _, theme in ipairs(themes) do
    theme_ids_by_colorscheme[theme.colorscheme] = theme.id
  end
end

local function persist_current_colorscheme()
  local theme_id = theme_ids_by_colorscheme[vim.g.colors_name]
  if not theme_id then
    return
  end

  current_index = find_index(theme_id) or current_index
  save_theme({ id = theme_id })
end

find_index = function(id)
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
  if opts.persist ~= false then
    save_theme(theme)
  end
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

function M.pick()
  vim.ui.select(themes, {
    prompt = 'Select theme',
    format_item = function(theme)
      if theme.label and theme.label ~= theme.id then
        return string.format('%s (%s)', theme.label, theme.id)
      end

      return theme.label or theme.id
    end,
  }, function(choice)
    if choice then
      M.set(choice.id)
    end
  end)
end

function M.setup(opts)
  opts = opts or {}
  if opts.themes then
    themes = opts.themes
  end
  rebuild_theme_lookup()

  local saved_theme = load_saved_theme()
  if saved_theme and find_index(saved_theme) then
    current_index = find_index(saved_theme) or current_index
  elseif opts.default then
    current_index = find_index(opts.default) or current_index
  end

  apply(themes[current_index], { silent = true })

  local group = vim.api.nvim_create_augroup('mflkee-colorswitcher', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = persist_current_colorscheme,
    desc = 'Persist known colorscheme selections',
  })

  vim.keymap.set('n', '<leader>tn', M.next, { desc = 'Theme next' })
  vim.keymap.set('n', '<leader>tp', M.prev, { desc = 'Theme previous' })
  vim.keymap.set('n', '<leader>tt', M.pick, { desc = 'Theme picker' })
  vim.api.nvim_create_user_command('ThemeNext', M.next, { desc = 'Next colorscheme' })
  vim.api.nvim_create_user_command('ThemePrev', M.prev, { desc = 'Previous colorscheme' })
  vim.api.nvim_create_user_command('ThemePick', M.pick, { desc = 'Pick colorscheme from a list' })
  vim.api.nvim_create_user_command('ThemeSet', function(cmd)
    M.set(cmd.args)
  end, { desc = 'Set colorscheme by id', nargs = 1, complete = function()
    return vim.tbl_map(function(theme)
      return theme.id
    end, themes)
  end })
end

return M
