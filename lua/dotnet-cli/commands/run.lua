-- dotnet-cli.nvim commands: Run
local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

---@type CometCommand
M.spec = {
  name = "Run",
  icon = " ",
  icon_hl = "String",
  desc = "dotnet run --project",
  action = function(ctx)
    common.project(ctx, function(f, c)
      local state = workspace.current()
      local cmd = { "dotnet", "run", "--project", f, "-c", state.configuration }
      if state.tfm then
        vim.list_extend(cmd, { "-f", state.tfm })
      end
      if state.profile then
        vim.list_extend(cmd, { "--launch-profile", state.profile })
      end
      common.run(c, cmd, { cwd = state.root, interactive = true })
    end)
  end,
}

return M
