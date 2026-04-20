-- dotnet-cli.nvim commands: Add Package (NEW)
-- Search and add NuGet packages to a project.
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Add Package",
  icon = "󰏗 ",
  icon_hl = "DiagnosticOk",
  desc = "dotnet add package",
  action = function(ctx)
    vim.cmd("stopinsert")
    vim.ui.input({ prompt = "Package name: " }, function(pkg)
      if not pkg or pkg == "" then
        return
      end
      vim.schedule(function()
        project.select_csproj(ctx, function(f, c)
          local cmd = { "dotnet", "add", f, "package", pkg }
          job.run(cmd, c)
        end)
      end)
    end)
  end,
}

return M
