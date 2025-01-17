return {
  {
    'voldikss/vim-translator',
    config = function()
      -- Настройки для vim-translator
      vim.g.translator_target_lang = 'ru' -- Перевод на русский язык
      vim.g.translator_default_engines = { 'google', 'bing' } -- Использование Google и Bing для перевода

      -- Привязка клавиши для перевода выделенного текста
      vim.keymap.set('v', '<leader>t', ':Translate<CR>', { noremap = true, silent = true })
    end,
  },
}
