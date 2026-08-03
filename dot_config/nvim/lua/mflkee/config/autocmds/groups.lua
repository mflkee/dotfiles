return {
  general = vim.api.nvim_create_augroup('General', { clear = true }),
  terminal = vim.api.nvim_create_augroup('Terminal', { clear = true }),
  language = vim.api.nvim_create_augroup('LanguageSpecific', { clear = true }),
  sql = vim.api.nvim_create_augroup('SQL', { clear = true }),
  plantuml = vim.api.nvim_create_augroup('PlantUML', { clear = true }),
  format = vim.api.nvim_create_augroup('Format', { clear = true }),
  autosave = vim.api.nvim_create_augroup('Autosave', { clear = true }),
}
