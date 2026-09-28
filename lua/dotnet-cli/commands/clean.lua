-- dotnet-cli.nvim commands: Clean
local common = require("dotnet-cli.commands.common")

local M = {}

---@type CometCommand
M.spec = {
  name = "Clean",
  icon = "󰃢 ",
  icon_hl = "DiagnosticError",
  desc = "dotnet clean",
  action = function(ctx)
    common.project(ctx, function(f, c)
      common.run(c, { "dotnet", "clean", f })
    end)
  end,
}

return M
