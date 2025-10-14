return {
  'mrcjkb/rustaceanvim',
  version = '^5', -- Recommended
  lazy = false, -- This plugin is important for Rust, so we want it to load early
  ft = { 'rust' },
  config = function()
    -- Configuration is handled via global vim.g.rustaceanvim
    -- which is set up in the lsp/rust.lua file
  end,
}