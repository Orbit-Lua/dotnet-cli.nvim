-- dotnet-cli.nvim commands: Test
local testing = require("dotnet-cli.commands.testing")
local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

---@type CometCommand
M.spec = {
  name = "Test",
  icon = " ",
  icon_hl = "DiagnosticHint",
  desc = "dotnet test",
  action = function(ctx)
    common.project(ctx, function(f, c)
      local state = workspace.current()
      common.run(
        c,
        testing.command(f, "all", {
          root = state.root,
          configuration = state.configuration,
          tfm = state.tfm,
        })
      )
    end)
  end,
}

return M
