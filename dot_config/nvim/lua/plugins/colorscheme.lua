-- persist every user-initiated colorscheme change (native <leader>uC,
-- :colorscheme); startup defaults don't count because nothing fires before
-- vim.g.colorscheme_ready is set by the restore below
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function(args)
    if vim.g.colorscheme_ready then
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
  if saved and not fn.apply_colorscheme(saved) then
    fn.forget_colorscheme()
  end
  vim.g.colorscheme_ready = true
end, 200)

-- drop the manual pick and go back to system/matugen-driven theming
vim.api.nvim_create_user_command('ThemeAuto', function()
  require('config.functions').forget_colorscheme()
  require('matugen').setup()
  vim.notify 'Theme: following matugen/system colors'
end, { desc = 'Follow system matugen theme' })

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
  { 'navarasu/onedark.nvim', lazy = true },
}
