-- dotnet-cli.nvim commands: Clean
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Clean",
  icon = "󰃢 ",
  icon_hl = "DiagnosticError",
  desc = "dotnet clean",
  action = function(ctx)
    project.select_csproj(ctx, function(f, c)
      job.run({ "dotnet", "clean", f }, c)
    end)
  end,
}

return M
