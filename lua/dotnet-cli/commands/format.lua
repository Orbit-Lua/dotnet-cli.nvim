-- dotnet-cli.nvim commands: Format (NEW)
-- Run `dotnet format` on the project or solution.
local project = require("dotnet-cli.project")
local common = require("dotnet-cli.commands.common")

local M = {}

---@type CometCommand
M.spec = {
  name = "Format",
  icon = "󰉢 ",
  icon_hl = "DiagnosticInfo",
  desc = "dotnet format",
  action = function(ctx)
    local slns = project.get_sln_files()
    if #slns > 0 then
      project.select_sln(ctx, function(sln, c)
        common.run(c, { "dotnet", "format", sln })
      end)
    else
      common.project(ctx, function(f, c)
        common.run(c, { "dotnet", "format", f })
      end)
    end
  end,
}

return M
