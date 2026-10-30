-- dotnet-cli.nvim commands: Build
local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

---@param name string
---@return string icon
---@return string icon_hl
local function get_config_icon(name)
  local lower = name:lower()
  if lower == "debug" then
    return "󰃤 ", "DiagnosticWarn"
  end
  if lower == "release" then
    return "󰑊 ", "DiagnosticOk"
  end
  return "󰒓 ", "DiagnosticInfo"
end

M.get_cmd = require("dotnet-cli.build").argv

---@type CometCommand
M.spec = {
  name = "Build",
  icon = "󰒓 ",
  icon_hl = "DiagnosticOk",
  desc = "dotnet build",
  action = function(ctx)
    local captured = workspace.current()
    local cfg = require("dotnet-cli.config").get()
    local configs = cfg.build_configurations
    if not configs or #configs == 0 then
      configs = { cfg.default_build_config }
    end

    local items = {}
    for _, name in ipairs(configs) do
      local icon, icon_hl = get_config_icon(name)
      table.insert(items, {
        _raw = name,
        icon = icon,
        icon_hl = icon_hl,
        name = name,
      })
    end

    ctx:select(items, {
      title = "Build Configuration",
      on_select = function(item, c)
        if not workspace.matches(captured) then
          c:append("Workspace changed; reopen Build")
          return
        end
        local config = item._raw
        common.project(c, function(f, c2)
          workspace.set({ configuration = config })
          common.run(
            c2,
            M.get_cmd(
              f,
              config,
              workspace.current().tfm,
              workspace.current().root
            ),
            { cwd = workspace.current().root }
          )
        end)
      end,
    })
  end,
}

return M
