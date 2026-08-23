return {
  'RRethy/base16-nvim',
  config = function()
    -- wrap matugen so a manual colorscheme pick (state file) wins over
    -- system/matugen theming; :ThemeAuto re-enables system-driven theming
    local ok, matugen = pcall(require, 'matugen')
    if ok then
      local orig = matugen.setup
      matugen.setup = function(...)
        if require('config.functions').get_saved_colorscheme() then
          return
        end
        return orig(...)
      end
      matugen.setup()
    end
  end,
}
