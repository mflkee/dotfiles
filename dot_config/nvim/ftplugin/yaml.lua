vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.opt_local.expandtab = true
vim.opt_local.smartindent = false
vim.opt_local.autoindent = true
vim.opt_local.indentexpr = "GetYAMLIndent(v:lnum)"
vim.opt_local.indentkeys = "0#,!^F,o,O"
vim.opt_local.formatoptions:remove({ "c", "r", "o" })
