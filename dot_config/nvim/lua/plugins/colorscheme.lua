-- restore the theme picked via <leader>uC once startup plugins are done
-- loading (base16/matugen applies its palette during startup, so restoring
-- earlier would get overridden)
vim.defer_fn(function()
  local fn = require 'config.functions'
  local saved = fn.get_saved_colorscheme()
  if saved and vim.g.colors_name ~= saved then
    fn.apply_colorscheme(saved)
  end
end, 200)

return {
  {
    'scottmckendry/cyberdream.nvim',
    priority = 1000,
    lazy = false,
    config = function()
      require('cyberdream').setup {}
      vim.cmd.colorscheme 'cyberdream'
    end,
  },
  -- additional themes for the picker (lazy-loaded on demand via :colorscheme)
  { 'catppuccin/nvim', lazy = true },
  { 'rebelot/kanagawa.nvim', lazy = true },
  { 'sainnhe/gruvbox-material', lazy = true },
  { 'maxmx03/dracula.nvim', lazy = true },
  { 'Mofiqul/vscode.nvim', lazy = true },
}
