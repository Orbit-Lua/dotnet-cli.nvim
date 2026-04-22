-- dotnet-cli.nvim commands: Run
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Run",
  icon = "󰐊 ",
  icon_hl = "String",
  desc = "dotnet run --project",
  action = function(ctx)
    project.select_csproj(ctx, function(f, c)
      local job_id = job.run({ "dotnet", "run", "--project", f }, c)
      project._current_running_project = f
      ctx.start_async_task(job_id)
    end)
  end,
}

return M
