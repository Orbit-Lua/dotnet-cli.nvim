-- dotnet-cli.nvim commands: Restore
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Restore",
  icon = "󰁨 ",
  icon_hl = "DiagnosticWarn",
  desc = "dotnet restore packages",
  action = function(ctx)
    project.select_csproj(ctx, function(f, c)
      c:start_async_task(job.run({ "dotnet", "restore", f }, c))
    end)
  end,
}

return M
