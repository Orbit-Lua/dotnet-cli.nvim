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
      local job_id = job.run({ "dotnet", "clean", f }, c)

      ctx.set_abort(function()
        vim.fn.jobstop(job_id)
        ctx.append("\n[Process Terminated by User]")
        ctx.set_abort(nil)
      end)
    end)
  end,
}

return M
