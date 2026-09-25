vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.expandtab = true
vim.opt_local.smartindent = true
vim.opt_local.autoindent = true
vim.opt_local.cindent = true
vim.opt_local.indentexpr = "GetRustIndent(v:lnum)"
vim.opt_local.formatoptions:remove({ "c", "r", "o" })
