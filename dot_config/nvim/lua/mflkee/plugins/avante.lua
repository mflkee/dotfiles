return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- Не использовать "*"!
  opts = {
    provider = "deepseek",
    vendors = {
      openrouter = {
        __inherited_from = "openai",
        api_key_name = "OPENROUTER_API_KEY", -- API-ключ передается через переменную окружения
        endpoint = "https://openrouter.ai/api/v1",
        model = "qwen/qwen-2.5-coder-32b-instruct:free",
        disable_tools = true, -- отключаем инструменты, чтобы избежать ошибки 404
      },
      deepseek = {
        __inherited_from = "openai",
        api_key_name = "OPENROUTER_API_KEY", -- тот же ключ, что и для OpenRouter
        endpoint = "https://openrouter.ai/api/v1",
        model = "deepseek/deepseek-v3-base:free",
        disable_tools = true,
      }
    },
  },
  build = "make",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "echasnovski/mini.pick",
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "ibhagwan/fzf-lua",
    "nvim-tree/nvim-web-devicons",
    "zbirenbaum/copilot.lua",
    {
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = { insert_mode = true },
          use_absolute_path = true,
        },
      },
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = { file_types = { "markdown", "Avante" } },
      ft = { "markdown", "Avante" },
    },
  },
}
