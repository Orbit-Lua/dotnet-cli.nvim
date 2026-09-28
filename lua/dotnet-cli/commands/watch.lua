-- dotnet-cli.nvim commands: Watch (NEW)
-- Hot-reload development with `dotnet watch`.
local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

---@type CometCommand
M.spec = {
  name = "Watch",
  icon = "󰥔 ",
  icon_hl = "DiagnosticWarn",
  desc = "dotnet watch (hot reload)",
  action = function(ctx)
    ctx:select({
      { _raw = "run", icon = " ", icon_hl = "String", name = "Watch Run" },
      {
        _raw = "test",
        icon = " ",
        icon_hl = "DiagnosticHint",
        name = "Watch Test",
      },
    }, {
      title = "Watch Mode",
      on_select = function(item, c)
        local mode = item._raw
        common.project(c, function(f, c2)
          local cmd = { "dotnet", "watch", mode, "--project", f }
          local state = workspace.current()
          common.run(c2, cmd, { cwd = state.root, interactive = true })
        end)
      end,
    })
  end,
}

return M
