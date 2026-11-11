 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#111111',
    base01 = '#121212',
    base02 = '#1c1c1c',
    base03 = '#606060',
    base04 = '#636363',
    base05 = '#828282',
    base06 = '#828282',
    base07 = '#828282',
    base08 = '#dddddd',
    base09 = '#cccccc',
    base0A = '#a7a7a7',
    base0B = '#aaaaaa',
    base0C = '#e99696',
    base0D = '#e99696',
    base0E = '#e99696',
    base0F = '#f4bebe',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#828282',          bg = '#111111' })
  hi('TelescopeBorder',         { fg = '#606060',             bg = '#111111' })
  hi('TelescopePromptNormal',   { fg = '#828282',          bg = '#111111' })
  hi('TelescopePromptBorder',   { fg = '#606060',             bg = '#111111' })
  hi('TelescopePromptPrefix',   { fg = '#aaaaaa',             bg = '#111111' })
  hi('TelescopePromptCounter',  { fg = '#636363',  bg = '#111111' })
  hi('TelescopePromptTitle',    { fg = '#111111',             bg = '#aaaaaa' })
  hi('TelescopePreviewTitle',   { fg = '#111111',             bg = '#a7a7a7' })
  hi('TelescopeResultsTitle',   { fg = '#111111',             bg = '#cccccc' })
  hi('TelescopeSelection',      { fg = '#828282',          bg = '#1c1c1c' })
  hi('TelescopeSelectionCaret', { fg = '#aaaaaa',             bg = '#1c1c1c' })
  hi('TelescopeMatching',       { fg = '#aaaaaa',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#828282',          bg = '#111111' })
  hi('MiniPickBorder',         { fg = '#606060',             bg = '#111111' })
  hi('MiniPickPrompt',   { fg = '#828282',          bg = '#111111' })
  hi('MiniPickPromptPrefix',   { fg = '#aaaaaa',             bg = '#111111' })
  hi('MiniPickBorderText',    { fg = '#111111',             bg = '#aaaaaa' })
  hi('MiniPickMatchCurrent',      { fg = '#828282',          bg = '#1c1c1c' })
  hi('MiniPickPromptCaret', { fg = '#aaaaaa',             bg = '#1c1c1c' })
  hi('MiniPickMatchRanges',       { fg = '#aaaaaa',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
