-- dotnet-cli.nvim commands: Restore
local common = require("dotnet-cli.commands.common")

local M = {}

---@type CometCommand
M.spec = {
  name = "Restore",
  icon = "󰁨 ",
  icon_hl = "DiagnosticWarn",
  desc = "dotnet restore packages",
  action = function(ctx)
    common.project(ctx, function(f, c)
      common.run(c, { "dotnet", "restore", f })
    end)
  end,
}

return M
