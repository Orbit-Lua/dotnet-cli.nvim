-- dotnet-cli.nvim commands: NuGet Sources
local job = require("dotnet-cli.job")
local parsers = require("dotnet-cli.parsers")
local config = require("dotnet-cli.config")

local M = {}

local function list_sources(c)
  job.run({ "dotnet", "nuget", "list", "source" }, c)
end

local function add_source(c)
  vim.cmd("stopinsert")
  vim.ui.input({ prompt = "Source name: " }, function(name)
    if not name or name == "" then
      return
    end
    vim.ui.input({ prompt = "Source URL: " }, function(url)
      if not url or url == "" then
        return
      end
      local cmd = { "dotnet", "nuget", "add", "source", url, "-n", name }
      if config.get().nuget.allow_insecure_connections then
        cmd[#cmd + 1] = "--allow-insecure-connections"
      end
      vim.schedule(function()
        job.run(cmd, c)
      end)
    end)
  end)
end

---Run one NuGet source action for each selected source and report a summary.
---@param action "remove"|"enable"|"disable"
---@param selected { _raw: string }[]
---@param c CometCtx
local function run_for_sources(action, selected, c)
  local failed = 0
  c:clear()
  for index, item in ipairs(selected) do
    local cmd = { "dotnet", "nuget", action, "source", item._raw }
    c:append("$ " .. table.concat(cmd, " "))
    local out, ok = job.run_sync(cmd)
    if ok then
      c:write(out)
      c:append("✓  " .. action .. ": " .. item._raw)
    else
      failed = failed + 1
      c:append("✗  Failed: " .. item._raw)
    end
    if index < #selected then
      c:append("")
    end
  end
  c:append("")
  if failed == 0 then
    c:append("✓  All " .. #selected .. " source(s) processed successfully")
  else
    c:append("✗  " .. failed .. " of " .. #selected .. " source(s) failed")
  end
end

---Pick sources, then run a remove, enable or disable action on them.
---@param action "remove"|"enable"|"disable"
---@param c CometCtx
local function change_sources(action, c)
  c:clear()
  local raw, ok = job.run_sync({ "dotnet", "nuget", "list", "source" })
  if not ok then
    c:append("Failed to list NuGet sources.")
    return
  end
  local sources = parsers.nuget_sources(raw)
  if #sources == 0 then
    c:append("No NuGet sources found.")
    return
  end

  local items = {}
  for _, source in ipairs(sources) do
    local state = source.enabled and "Enabled" or "Disabled"
    items[#items + 1] = {
      _raw = source.name,
      icon = source.enabled and "󰔡 " or "󰨙 ",
      icon_hl = source.enabled and "DiagnosticOk" or "DiagnosticWarn",
      name = source.name .. "  (" .. state .. ")  " .. source.url,
    }
  end
  c:select(items, {
    title = action:sub(1, 1):upper() .. action:sub(2) .. " Source",
    multi_select = true,
    on_select = function(selected, c2)
      run_for_sources(action, selected, c2)
    end,
  })
end

local handlers = {
  list = list_sources,
  add = add_source,
}

local actions = {
  { _raw = "list", icon = "󰈚 ", icon_hl = "Comment", name = "List Sources" },
  {
    _raw = "add",
    icon = "󰐕 ",
    icon_hl = "DiagnosticOk",
    name = "Add Source",
  },
  {
    _raw = "remove",
    icon = "󰍴 ",
    icon_hl = "DiagnosticError",
    name = "Remove Source",
  },
  {
    _raw = "enable",
    icon = "󰔡 ",
    icon_hl = "DiagnosticOk",
    name = "Enable Source",
  },
  {
    _raw = "disable",
    icon = "󰨙 ",
    icon_hl = "DiagnosticWarn",
    name = "Disable Source",
  },
}

---@type CometCommand
M.spec = {
  name = "NuGet Sources",
  icon = "󰏗 ",
  icon_hl = "DiagnosticHint",
  desc = "manage NuGet package sources",
  action = function(ctx)
    ctx:select(vim.deepcopy(actions), {
      title = "NuGet Sources",
      on_select = function(item, c)
        local handler = handlers[item._raw]
        if handler then
          handler(c)
        else
          change_sources(item._raw, c)
        end
      end,
    })
  end,
}

return M
