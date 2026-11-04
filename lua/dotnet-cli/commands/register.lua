-- `Dotnet*` user commands that work without the manager UI.
local workspace = require("dotnet-cli.workspace")
local project = require("dotnet-cli.project")
local job = require("dotnet-cli.job")
local M = {}

local title = "Dotnet"

---@param message string
---@param level integer
local function notify(message, level)
  vim.notify(message, level, { title = title })
end

---Run a command and report its start and its result.
---@param cmd string[]
---@param messages { start: string, ok: string, fail: string }
---@param root string
local function run_notified(cmd, messages, root)
  notify(messages.start, vim.log.levels.INFO)
  job.run(cmd, nil, nil, {
    cwd = root,
    on_exit = function(code)
      vim.schedule(function()
        if code == 0 then
          notify(messages.ok, vim.log.levels.INFO)
        else
          notify(messages.fail, vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

---Pick a project under the working directory and select it in the workspace.
---A workspace change while the scan or the picker runs drops the result.
---@param prompt string
---@param on_pick fun(path: string, chosen: DotnetCliWorkspaceContext, root: string)
local function pick_project(prompt, on_pick)
  local root = vim.fs.normalize(vim.fn.getcwd())
  local captured = workspace.activate(root)
  local buffer = vim.api.nvim_get_current_buf()
  notify("Scanning .NET projects…", vim.log.levels.INFO)
  project.get_csproj_files_async(root, function(files)
    if not workspace.matches(captured, buffer) then
      return
    end
    if #files == 0 then
      notify("No .csproj files found", vim.log.levels.WARN)
      return
    end
    vim.ui.select(files, { prompt = prompt }, function(file)
      if not file or not workspace.matches(captured, buffer) then
        return
      end
      local path = vim.fs.joinpath(root, file)
      local chosen = workspace.select_project(path, { root = captured.root })
      on_pick(path, chosen, captured.root)
    end)
  end)
end

local function build_command()
  local build_cmd = require("dotnet-cli.commands.build")
  pick_project("Choose project to build", function(path, chosen, root)
    run_notified(
      build_cmd.get_cmd(path, chosen.configuration, chosen.tfm, chosen.root),
      { start = "Building…", ok = "Build succeeded", fail = "Build failed" },
      root
    )
  end)
end

local function publish_command()
  local publish_cmd = require("dotnet-cli.commands.publish")
  pick_project("Choose project to publish", function(path, _, root)
    run_notified(publish_cmd.get_cmd(path), {
      start = "Publishing…",
      ok = "Publish succeeded",
      fail = "Publish failed",
    }, root)
  end)
end

---@param existing string
---@param version string
local function update_global_json(existing, version)
  if not require("dotnet-cli.sdk").set_global_json_version(version) then
    notify("Failed to parse existing global.json", vim.log.levels.ERROR)
    return
  end
  notify(
    "Updated global.json (SDK " .. existing .. " → " .. version .. ")",
    vim.log.levels.INFO
  )
end

---@param version string
local function create_global_json(version)
  local output, ok = job.run_sync({
    "dotnet",
    "new",
    "globaljson",
    "--sdk-version",
    version,
  })
  if ok then
    notify("Created global.json (SDK " .. version .. ")", vim.log.levels.INFO)
  else
    notify("Error: " .. table.concat(output, "\n"), vim.log.levels.ERROR)
  end
end

local function global_json_command()
  local existing = require("dotnet-cli.sdk").global_json_version()
  local sdk_lines, sdk_ok = job.run_sync({ "dotnet", "--list-sdks" })
  if not sdk_ok or #sdk_lines == 0 then
    notify("Failed to retrieve SDK list.", vim.log.levels.ERROR)
    return
  end
  local choices = {}
  for i = #sdk_lines, 1, -1 do
    choices[#choices + 1] = (sdk_lines[i]:gsub("[\r\n]", ""))
  end
  local prompt = existing
      and ("Current: " .. existing .. " — Select new SDK version:")
    or "Select .NET SDK version:"
  vim.ui.select(choices, { prompt = prompt }, function(choice)
    local version = choice and choice:match("^(%S+)")
    if not version then
      return
    end
    if existing then
      update_global_json(existing, version)
    else
      create_global_json(version)
    end
  end)
end

---@param action fun(): boolean, string?
---@return fun()
local function report_failure(action)
  return function()
    local ok, err = action()
    if not ok then
      notify(err or "Unknown error", vim.log.levels.ERROR)
    end
  end
end

---Register the `Dotnet*` user commands.
---@param notification_title string title of command notifications
function M.setup(notification_title)
  title = notification_title
  local command = vim.api.nvim_create_user_command
  command("DotnetBuild", build_command, { desc = "Dotnet Build" })
  command("DotnetPublish", publish_command, { desc = "Dotnet Publish" })
  command("DotnetGlobalJson", global_json_command, {
    desc = "Dotnet global.json – pin SDK version",
  })
  command("DotnetManager", function()
    require("dotnet-cli").open()
  end, { desc = "Open Dotnet Manager UI" })
  command(
    "DotnetDebug",
    report_failure(function()
      return require("dotnet-cli.dap").launch()
    end),
    { desc = "Debug selected .NET project" }
  )
  command(
    "DotnetAttach",
    report_failure(function()
      return require("dotnet-cli.dap").attach()
    end),
    { desc = "Attach .NET debugger to a local process" }
  )
end

return M
