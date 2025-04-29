return {
  -- Подсветка синтаксиса
  {
    "aklt/plantuml-syntax",
    ft = "plantuml",
  },

  -- Превью в браузере
  {
    "weirongxu/plantuml-previewer.vim",
    dependencies = { "tyru/open-browser.vim" },
    ft = "plantuml",
    init = function()
      -- Укажите явный путь к plantuml (JAR или бинарник)
      vim.g.plantuml_previewer_plantuml_jar_path = "~/.local/bin/plantuml.jar"
      -- Или для бинарной версии:
      -- vim.g.plantuml_previewer_cmd = "/usr/bin/plantuml"

      -- Клавиша для открытия в браузере
      vim.keymap.set("n", "<leader>pp", ":PlantumlOpen<CR>", {
        silent = true,
        desc = "Open PlantUML preview in browser"
      })
    end,
  },
}
