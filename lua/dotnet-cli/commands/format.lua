-- dotnet-cli.nvim commands: Format (NEW)
-- Run `dotnet format` on the project or solution.
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Format",
  icon = "󰉢 ",
  icon_hl = "DiagnosticInfo",
  desc = "dotnet format",
  action = function(ctx)
    local slns = project.get_sln_files()
    local job_id = nil
    if #slns > 0 then
      -- Prefer formatting the solution if one exists
      project.select_sln(ctx, function(sln, c)
        job_id = job.run({ "dotnet", "format", sln }, c)
      end)
    else
      project.select_csproj(ctx, function(f, c)
        job_id = job.run({ "dotnet", "format", f }, c)
      end)
    end

    if job_id then
      ctx.set_abort(function()
        vim.fn.jobstop(job_id)
        ctx.append("\n[Process Terminated by User]")
        ctx.set_abort(nil)
      end)
    end
  end,
}

return M
