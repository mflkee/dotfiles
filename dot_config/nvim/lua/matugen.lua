local M = {}

function M.setup()
  require('base16-colorscheme').setup {
    base00 = '#0b0e14', base01 = '#131721', base02 = '#202229', base03 = '#3e4b59',
    base04 = '#bfbdb6', base05 = '#e6e1cf', base06 = '#ece8db', base07 = '#f2f0e7',
    base08 = '#f07178', base09 = '#ff8f40', base0A = '#ffb454', base0B = '#aad94c',
    base0C = '#95e6cb', base0D = '#59c2ff', base0E = '#d2a6ff', base0F = '#e6b450',
  }

  local hi = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end

  hi('TelescopeNormal', { fg = '#e6e1cf', bg = '#0b0e14' })
  hi('TelescopeBorder', { fg = '#3e4b59', bg = '#0b0e14' })
  hi('TelescopePromptNormal', { fg = '#e6e1cf', bg = '#0b0e14' })
  hi('TelescopePromptBorder', { fg = '#3e4b59', bg = '#0b0e14' })
  hi('TelescopePromptPrefix', { fg = '#e6e1cf', bg = '#0b0e14' })
  hi('TelescopePromptCounter', { fg = '#bfbdb6', bg = '#0b0e14' })
  hi('TelescopePromptTitle', { fg = '#0b0e14', bg = '#e6b450' })
  hi('TelescopePreviewTitle', { fg = '#0b0e14', bg = '#aad94c' })
  hi('TelescopeResultsTitle', { fg = '#0b0e14', bg = '#d2a6ff' })
  hi('TelescopeSelection', { fg = '#e6e1cf', bg = '#202229' })
  hi('TelescopeSelectionCaret', { fg = '#e6b450', bg = '#202229' })
  hi('TelescopeMatching', { fg = '#e6b450', bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates)
local signal = vim.uv.new_signal()
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    pcall(function() require('matugen').setup() end)
  end)
)

return M