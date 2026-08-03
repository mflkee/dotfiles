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
}
