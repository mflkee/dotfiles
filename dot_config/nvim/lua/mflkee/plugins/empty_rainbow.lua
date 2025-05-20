return {
  "HiPhish/rainbow-delimiters.nvim",
  config = function()
    local rd = require("rainbow-delimiters")
    require("rainbow-delimiters.setup").setup {
      strategy = { [""] = rd.strategy.global },
      query    = { [""] = "rainbow-delimiters" },
      -- имена групп оставляем стандартные:
      highlight = {
        "RainbowDelimiterCyan",
        "RainbowDelimiterViolet",
        "RainbowDelimiterOrange",
        "RainbowDelimiterRed",
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterGreen",
      },
    }
  end,
}
