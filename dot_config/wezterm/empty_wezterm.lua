local wezterm = require 'wezterm'

return {
  -- Шрифт с лигатурами (например, FiraCode)
  font = wezterm.font("FiraCode Nerd Font", { weight = "Regular" }),
  font_size = 14.0,

  -- Включение лигатур
  harfbuzz_features = { "calt=1", "clig=1", "liga=1" },

  -- Цветовая схема
  color_scheme = "Dracula",

  -- Прозрачность окна
  window_background_opacity = 0.5,

  -- Включение вкладок
  enable_tab_bar = true,
  hide_tab_bar_if_only_one_tab = true,

  -- Настройки курсора
  default_cursor_style = "SteadyBlock",

  -- Отключение предупреждений
  warn_about_missing_glyphs = false,

  -- Настройки окна
  initial_cols = 120,
  initial_rows = 30,
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },

  -- Горячие клавиши
  keys = {
    -- Создание новой вкладки (Ctrl + T)
    { key = "t", mods = "CTRL", action = wezterm.action { SpawnTab = "CurrentPaneDomain" } },

    -- Переключение на предыдущую вкладку (Ctrl + [)
    { key = "[", mods = "CTRL", action = wezterm.action { ActivateTabRelative = -1 } },

    -- Переключение на следующую вкладку (Ctrl + ])
    { key = "]", mods = "CTRL", action = wezterm.action { ActivateTabRelative = 1 } },

    -- Вертикальное разделение (Ctrl + Shift + %)
    { key = "%", mods = "CTRL|SHIFT", action = wezterm.action { SplitVertical = { domain = "CurrentPaneDomain" } } },

    -- Горизонтальное разделение (Ctrl + Shift + ")
    { key = "\"", mods = "CTRL|SHIFT", action = wezterm.action { SplitHorizontal = { domain = "CurrentPaneDomain" } } },
      -- Переименование вкладки (Ctrl + Shift + R)
    { key = "r", mods = "CTRL|SHIFT", action = wezterm.action.PromptInputLine {
        description = "Enter new tab name",
        action = wezterm.action_callback(function(window, pane, line)
          if line then
            window:active_tab():set_title(line)
          end
        end),
      },
    },
  },
}
