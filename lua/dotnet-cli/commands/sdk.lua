-- dotnet-cli.nvim commands: SDK Management
local job = require("dotnet-cli.job")
local sdk = require("dotnet-cli.sdk")

local M = {}

---@type CometCommand
M.spec_list_sdks = {
  name = "List SDKs",
  icon = "󰈚 ",
  icon_hl = "Comment",
  desc = "dotnet --list-sdks",
  action = function(ctx)
    ctx:clear()
    ctx:append("$ dotnet --list-sdks")
    ctx:append("")
    local lines, ok = job.run_sync({ "dotnet", "--list-sdks" })
    if not ok then
      ctx:append("Command failed.")
    else
      ctx:write(lines)
    end
  end,
}

---@type CometCommand
M.spec_list_runtimes = {
  name = "List Runtimes",
  icon = "󰈚 ",
  icon_hl = "Comment",
  desc = "dotnet --list-runtimes",
  action = function(ctx)
    ctx:clear()
    ctx:append("$ dotnet --list-runtimes")
    ctx:append("")
    local lines, ok = job.run_sync({ "dotnet", "--list-runtimes" })
    if not ok then
      ctx:append("Command failed.")
    else
      ctx:write(lines)
    end
  end,
}

---@param c table Comet context
---@param existing string
---@param version string
local function update_global_json(c, existing, version)
  if not sdk.set_global_json_version(version) then
    c:append("✗  Failed to parse existing global.json")
    return
  end
  c:clear()
  c:append(
    "✓  Updated global.json  (SDK " .. existing .. " → " .. version .. ")"
  )
end

---@param c table Comet context
---@param version string
local function create_global_json(c, version)
  local cmd = "dotnet new globaljson --sdk-version " .. version
  c:clear()
  c:append("$ " .. cmd)
  c:append("")
  local out = vim.fn.system(cmd)
  if vim.v.shell_error == 0 then
    c:append("✓  Created global.json  (SDK " .. version .. ")")
  else
    c:append("✗  Error: " .. out)
  end
end

---@type CometCommand
M.spec_global_json = {
  name = "Global JSON",
  icon = "󰘦 ",
  icon_hl = "Special",
  desc = "pin SDK version via global.json",
  action = function(ctx)
    ctx:clear()
    local existing = sdk.global_json_version()
    if existing then
      ctx:append("Current SDK version: " .. existing)
      ctx:append("")
    end

    local sdk_lines, ok = job.run_sync({ "dotnet", "--list-sdks" })
    if not ok or #sdk_lines == 0 then
      ctx:append("Failed to list .NET SDKs. Is dotnet installed?")
      return
    end
    local choices = {}
    for i = #sdk_lines, 1, -1 do
      choices[#choices + 1] = (sdk_lines[i]:gsub("[\r\n]", ""))
    end

    ctx:select(choices, {
      title = "Select .NET SDK",
      on_select = function(choice, c)
        local version = choice:match("^(%S+)")
        if not version then
          c:append("Could not parse SDK version from: " .. choice)
        elseif existing then
          update_global_json(c, existing, version)
        else
          create_global_json(c, version)
        end
      end,
    })
  end,
}

return M
