-- Индикатор режима в mini.statusline: перекрашиваем MiniStatuslineMode* с
-- приглушённых линков (Cursor/Diff*/IncSearch) на акценты ayu-палитры.
-- Тёмный текст (#0b0e14 = base00) на цветном фоне, как и было задумано у
-- mini.statusline (fg = фоновая base00).
--
-- Переживает перекраску темы: ColorScheme (ручной :colorscheme) + SIGUSR1 от
-- matugen (см. after/plugin/codeblock_hl.lua — та же схема).

local mode_colors = {
  ['Normal'] = '#8e959e', -- спокойный серый
  ['Insert'] = '#e6b450', -- жёлтый (ayu-акцент)
  ['Visual'] = '#59c2ff', -- голубой
  ['Replace'] = '#d95757', -- красный
  ['Command'] = '#aad94c', -- зелёный
  ['Other'] = '#8ed8f1', -- циан
}

local function set()
  for mode, color in pairs(mode_colors) do
    vim.api.nvim_set_hl(0, 'MiniStatuslineMode' .. mode, { fg = '#0b0e14', bg = color })
  end
end

set()

vim.api.nvim_create_autocmd('ColorScheme', { callback = set })

-- SIGUSR1 (matugen live-update обоев)
if _G.__mode_hl_signal then
  _G.__mode_hl_signal:stop()
  _G.__mode_hl_signal:close()
end
local signal = vim.uv.new_signal()
_G.__mode_hl_signal = signal
signal:start('sigusr1', vim.schedule_wrap(function() set() end))
