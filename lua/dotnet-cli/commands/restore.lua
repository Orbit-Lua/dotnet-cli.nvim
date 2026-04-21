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
      local job_id = job.run({ "dotnet", "restore", f }, c)

      ctx.set_abort(function()
        vim.fn.jobstop(job_id)
        ctx.append("\n[Process Terminated by User]")
        ctx.set_abort(nil)
      end)
    end)
  end,
}

return M
