-- dotnet-cli.nvim commands: SDK Management
local job = require("dotnet-cli.job")

local M = {}

---@type CometCommand
M.spec_list_sdks = {
  name = "List SDKs",
  icon = "󰈚 ",
  icon_hl = "Comment",
  desc = "dotnet --list-sdks",
  action = function(ctx)
    ctx.clear()
    ctx.append("$ dotnet --list-sdks")
    ctx.append("")
    local lines, ok = job.run_sync("dotnet --list-sdks")
    if not ok then
      ctx.append("Command failed.")
    else
      ctx.write(lines)
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
    ctx.clear()
    ctx.append("$ dotnet --list-runtimes")
    ctx.append("")
    local lines, ok = job.run_sync("dotnet --list-runtimes")
    if not ok then
      ctx.append("Command failed.")
    else
      ctx.write(lines)
    end
  end,
}

---@type CometCommand
M.spec_global_json = {
  name = "Global JSON",
  icon = "󰘦 ",
  icon_hl = "Special",
  desc = "pin SDK version via global.json",
  action = function(ctx)
    ctx.clear()

    local existing_version
    if vim.fn.filereadable("global.json") == 1 then
      local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile("global.json"), "\n"))
      if ok and data and data.sdk and data.sdk.version then
        existing_version = data.sdk.version
        ctx.append("Current SDK version: " .. existing_version)
        ctx.append("")
      end
    end

    local sdk_lines, ok = job.run_sync("dotnet --list-sdks")
    if not ok or #sdk_lines == 0 then
      ctx.append("Failed to list .NET SDKs. Is dotnet installed?")
      return
    end

    local choices = {}
    for i = #sdk_lines, 1, -1 do
      table.insert(choices, (sdk_lines[i]:gsub("[\r\n]", "")))
    end

    ctx.select(choices, {
      title = "Select .NET SDK",
      on_select = function(choice, c)
        local version = choice:match("^(%S+)")
        if not version then
          c.append("Could not parse SDK version from: " .. choice)
          return
        end

        if existing_version then
          local raw = table.concat(vim.fn.readfile("global.json"), "\n")
          local parse_ok, data = pcall(vim.json.decode, raw)
          if parse_ok and data then
            data.sdk = data.sdk or {}
            data.sdk.version = version
            local encoded = vim.json.encode(data)
            vim.fn.writefile({ encoded }, "global.json")
            c.clear()
            c.append("✓  Updated global.json  (SDK " .. existing_version .. " → " .. version .. ")")
          else
            c.append("✗  Failed to parse existing global.json")
          end
        else
          local cmd = "dotnet new globaljson --sdk-version " .. version
          c.clear()
          c.append("$ " .. cmd)
          c.append("")
          local out = vim.fn.system(cmd)
          if vim.v.shell_error == 0 then
            c.append("✓  Created global.json  (SDK " .. version .. ")")
          else
            c.append("✗  Error: " .. out)
          end
        end
      end,
    })
  end,
}

return M
