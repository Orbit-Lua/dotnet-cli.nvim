local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

M.spec = {
  name = "Tools & Workloads",
  icon = "󰒓 ",
  desc = "local tool manifests and SDK workloads",
  action = function(ctx)
    ctx:select({
      {
        name = "List Local Tools",
        cmd = { "dotnet", "tool", "list", "--local" },
      },
      { name = "Restore Local Tools", cmd = { "dotnet", "tool", "restore" } },
      { name = "List Workloads", cmd = { "dotnet", "workload", "list" } },
      { name = "Restore Project Workloads", _raw = "workload_restore" },
    }, {
      title = "Tools & Workloads",
      on_select = function(item, child)
        if item.cmd then
          common.run(child, item.cmd, { cwd = workspace.current().root })
        else
          common.project(child, function(project, c)
            common.run(c, { "dotnet", "workload", "restore", project }, {
              cwd = workspace.current().root,
            })
          end)
        end
      end,
    })
  end,
}

return M
