-- Options are automatically loaded before lazy.nvim startup
-- Default options: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- mapleader defaults to " " in LazyVim.

-- Spell check English + Russian (incl. ё), so Russian words aren't flagged red.
-- Spell files: ~/.local/share/nvim/site/spell/ru.utf-8.{spl,sug}
vim.opt.spelllang = { "en", "ru_yo" }
