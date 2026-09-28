-- Подкрутка подсветки кода (в т.ч. блоков ```lang``` в markdown):
--   • палитра деревоситтер-групп @* в стиле ayu — глобально для всех языков,
--     плюс пример точечного оверрайда (@keyword.rust);
--   • фон кодового блока render-markdown (RenderMarkdownCode) вместо ColorColumn.
--
-- Переживает перекраску темы:
--   • событие ColorScheme (ручной :colorscheme);
--   • SIGUSR1 от matugen (обои→theme live-update): base16-colorscheme.setup
--     красит напрямую без ColorScheme, поэтому дублируем хендлер сигнала.
--     Хендлер зарегистрирован в after/plugin, т.е. позже matugen — вызывается
--     после него и возвращает наши цвета наверх.

local function set()
  -- Палитра кода (все языки сразу)
  vim.api.nvim_set_hl(0, '@keyword', { fg = '#e6b450', bold = true })
  vim.api.nvim_set_hl(0, '@string', { fg = '#aad94c' })
  vim.api.nvim_set_hl(0, '@function', { fg = '#59c2ff' })
  vim.api.nvim_set_hl(0, '@type', { fg = '#8ed8f1' })
  vim.api.nvim_set_hl(0, '@number', { fg = '#39bae6' })
  vim.api.nvim_set_hl(0, '@constant', { fg = '#39bae6' })
  vim.api.nvim_set_hl(0, '@comment', { fg = '#595f6a', italic = true })

  -- Точечно по языку (перекрывает глобальные @* только для rust)
  vim.api.nvim_set_hl(0, '@keyword.rust', { fg = '#e6b450', bold = true })

  -- Фон кодового блока в render-markdown (было: ColorColumn)
  vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = '#1e222a' })
end

set()

vim.api.nvim_create_autocmd('ColorScheme', { callback = set })

-- SIGUSR1 (matugen live-update обоев)
if _G.__codeblock_hl_signal then
  _G.__codeblock_hl_signal:stop()
  _G.__codeblock_hl_signal:close()
end
local signal = vim.uv.new_signal()
_G.__codeblock_hl_signal = signal
signal:start('sigusr1', vim.schedule_wrap(function() set() end))
