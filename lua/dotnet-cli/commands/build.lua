-- dotnet-cli.nvim commands: Build
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@param value string
---@return boolean
local function is_absolute_path(value)
  return value:match("^/") ~= nil or value:match("^%a:[/\\]") ~= nil
end

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

---@param proj? string
---@param config? string
---@return string[]
M.get_cmd = function(proj, config)
  local cfg = require("dotnet-cli.config").get()
  config = config or cfg.default_build_config

  local out_dir = cfg.output_dir_template:gsub("{config}", config)
  if not is_absolute_path(out_dir) then
    out_dir = vim.fs.joinpath(vim.fn.getcwd(), out_dir)
  end

  local cmd = { "dotnet", "build" }
  if proj and proj ~= "" then
    table.insert(cmd, proj)
  end
  vim.list_extend(cmd, { "-c", config, "-o", out_dir })
  return cmd
end

---@type CometCommand
M.spec = {
  name = "Build",
  icon = "󰒓 ",
  icon_hl = "DiagnosticOk",
  desc = "dotnet build",
  action = function(ctx)
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
        local config = item._raw
        project.select_csproj(c, function(f, c2)
          c2:start_async_task(job.run(M.get_cmd(f, config), c2))
        end)
      end,
    })
  end,
}

return M
