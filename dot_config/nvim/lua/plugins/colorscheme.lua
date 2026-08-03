return {
  {
    "Mofiqul/vscode.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      require("vscode").setup({ style = "dark" })
      vim.cmd.colorscheme("vscode")
    end,
  },
  -- additional themes for the picker (lazy-loaded on demand via :colorscheme)
  { "catppuccin/nvim", lazy = true },
  { "rebelot/kanagawa.nvim", lazy = true },
  { "sainnhe/gruvbox-material", lazy = true },
  { "maxmx03/dracula.nvim", lazy = true },
}
