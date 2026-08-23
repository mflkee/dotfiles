-- persist user-initiated colorscheme changes (native <leader>uC, :colorscheme);
-- startup defaults (cyberdream) and the matugen base16 palette are not persisted
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function(args)
    if vim.g.colorscheme_ready and not args.match:find '^base16' then
      require('config.functions').save_colorscheme(args.match)
    end
  end,
})

-- restore the saved theme once startup plugins are done loading
-- (base16/matugen applies its palette during startup, so restoring earlier
-- would get overridden)
vim.defer_fn(function()
  local fn = require 'config.functions'
  local saved = fn.get_saved_colorscheme()
  if saved then
    fn.apply_colorscheme(saved)
  end
  vim.g.colorscheme_ready = true
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
