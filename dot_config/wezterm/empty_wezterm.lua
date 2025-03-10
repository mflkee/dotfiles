local wezterm = require 'wezterm'

return {
  set_environment_variables = {
    TERM = "xterm-256color",
  },
  exit_behavior = "Close", -- Закрыть окно без подтверждения
  window_close_confirmation = "NeverPrompt", -- Никогда не запрашивать подтверждение
  -- Отключение предупреждений
  warn_about_missing_glyphs = false,

  enable_wayland = false, -- Если вы не используете Wayland, отключите его
  front_end = "OpenGL",   -- Используйте OpenGL для аппаратного ускорения
  -- Шрифт с лигатурами (например, FiraCode)
  font = wezterm.font("FiraCode Nerd Font", { weight = "Regular" }),
  font_size = 14.0,

  -- Включение лигатур
  harfbuzz_features = { "calt=1", "clig=1", "liga=1" },

  -- Цветовая схема
  color_scheme = "Dracula",

  -- Прозрачность окна
  window_background_opacity = 1.0,

  -- Включение вкладок
  enable_tab_bar = true,
  hide_tab_bar_if_only_one_tab = true,

  -- Настройки курсора
  default_cursor_style = "SteadyBlock",

  -- Настройки окна
  window_decorations = wezterm.WindowDecorations.NONE,
  window_startup_mode = "Maximized",

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

    -- Перемещение между панелями (Ctrl + Shift + hjkl)
    { key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "j", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "LeftArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Left", 5 } },
    { key = "DownArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Down", 5 } },
    { key = "UpArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Up", 5 } },
    { key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Right", 5 } },
  },
}
