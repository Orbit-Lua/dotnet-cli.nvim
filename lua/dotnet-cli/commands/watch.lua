-- dotnet-cli.nvim commands: Watch (NEW)
-- Hot-reload development with `dotnet watch`.
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Watch",
  icon = "󰥔 ",
  icon_hl = "DiagnosticWarn",
  desc = "dotnet watch (hot reload)",
  action = function(ctx)
    ctx.select({
      { _raw = "run", icon = "󰐊 ", icon_hl = "String", name = "Watch Run" },
      { _raw = "test", icon = "󰙨 ", icon_hl = "DiagnosticHint", name = "Watch Test" },
    }, {
      title = "Watch Mode",
      on_select = function(item, c)
        local mode = item._raw
        project.select_csproj(c, function(f, c2)
          local cmd = { "dotnet", "watch", mode, "--project", f }
          job.run(cmd, c2)
        end)
      end,
    })
  end,
}

return M
