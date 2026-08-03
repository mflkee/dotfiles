---@type LazySpec
return {
  "AstroNvim/astrocore",
  opts = {
    mappings = {
      n = {
        ["<A-Up>"]   = { function() require("config.functions").move_line("up") end,   desc = "Move line up" },
        ["<A-Down>"] = { function() require("config.functions").move_line("down") end, desc = "Move line down" },
      },
    },
  },
}
