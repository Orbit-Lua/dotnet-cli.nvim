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
      local job_id = job.run({ "dotnet", "test", f, "-v", "minimal" }, c)
      ctx.start_async_task(job_id)
    end)
  end,
}

return M
