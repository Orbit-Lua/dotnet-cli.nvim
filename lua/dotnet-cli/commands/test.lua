-- dotnet-cli.nvim commands: Test
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Test",
  icon = "󰙨 ",
  icon_hl = "DiagnosticHint",
  desc = "dotnet test",
  action = function(ctx)
    project.select_csproj(ctx, function(f, c)
      c:start_async_task(job.run({ "dotnet", "test", f, "-v", "minimal" }, c))
    end)
  end,
}

return M
