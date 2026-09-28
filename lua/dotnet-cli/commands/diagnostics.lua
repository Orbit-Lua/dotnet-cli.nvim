local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

local tools = {
  counters = { command = "dotnet-counters", extension = ".csv" },
  trace = { command = "dotnet-trace", extension = ".nettrace" },
  dump = { command = "dotnet-dump", extension = ".dmp" },
}

local function local_tool(root, command)
  local path = vim.fs.joinpath(root, ".config", "dotnet-tools.json")
  if vim.fn.filereadable(path) ~= 1 then
    return false
  end
  local ok, manifest =
    pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(manifest.tools) ~= "table" then
    return false
  end
  for _, tool in pairs(manifest.tools) do
    if tool.commands then
      for _, name in ipairs(tool.commands) do
        if name == command then
          return true
        end
      end
    end
  end
  return false
end

M.tool_cmd = function(tool, root, args)
  local info = tools[tool]
  assert(info, "unknown .NET diagnostic tool: " .. tostring(tool))
  local cmd
  if vim.fn.executable(info.command) == 1 then
    cmd = { info.command }
  elseif local_tool(root, info.command) then
    cmd = { "dotnet", "tool", "run", info.command, "--" }
  else
    return nil
  end
  vim.list_extend(cmd, args or {})
  return cmd
end

M.get_args = function(tool, pid, output)
  assert(tools[tool], "unknown .NET diagnostic tool: " .. tostring(tool))
  local cmd = { "collect", "--process-id", tostring(pid) }
  if tool == "counters" then
    vim.list_extend(cmd, { "--format", "csv", "--output", output })
  else
    vim.list_extend(cmd, { "--output", output })
  end
  return cmd
end

local function default_output(root, info)
  local dir = vim.fs.joinpath(root, "artifacts", "diagnostics")
  vim.fn.mkdir(dir, "p")
  return vim.fs.joinpath(
    dir,
    "capture-" .. os.date("%Y%m%d-%H%M%S") .. info.extension
  )
end

local function run_tool(tool, ctx)
  local info = tools[tool]
  local state = workspace.current()
  local cmd = M.tool_cmd(tool, state.root, {})
  if not cmd then
    ctx:clear()
    ctx:append(info.command .. " is unavailable.")
    ctx:append("Install it with: dotnet tool install --global " .. info.command)
    ctx:append(
      "Or add it to this repository's local tool manifest and run dotnet tool restore."
    )
    return
  end
  common.input("Target process ID: ", function(pid)
    if not pid:match("^%d+$") then
      ctx:append("Process ID must be a number.")
      return
    end
    local path = default_output(state.root, info)
    local full_cmd = M.tool_cmd(tool, state.root, M.get_args(tool, pid, path))
    ctx:append("Artifact: " .. path)
    common.run(
      ctx,
      full_cmd,
      { cwd = state.root, interactive = true, ctx_clear = false }
    )
  end)
end

M.spec = {
  name = ".NET Diagnostics",
  icon = "󰍉 ",
  desc = "collect local runtime counters, traces and dumps",
  action = function(ctx)
    ctx:select({
      { name = "Collect Counters", _raw = "counters" },
      { name = "Collect Trace", _raw = "trace" },
      { name = "Collect Dump", _raw = "dump" },
    }, {
      title = ".NET Diagnostics",
      on_select = function(item, child)
        run_tool(item._raw, child)
      end,
    })
  end,
}

return M
