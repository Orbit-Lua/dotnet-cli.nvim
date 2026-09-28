local job = require("dotnet-cli.job")
local launch = require("dotnet-cli.launch")
local msbuild = require("dotnet-cli.msbuild")
local workspace = require("dotnet-cli.workspace")

local M = {}

local adapter_type = "coreclr"

local function split_arguments(value)
  local result, current, quote = {}, "", nil
  local i = 1
  while i <= #value do
    local char = value:sub(i, i)
    local next_char = value:sub(i + 1, i + 1)
    if
      char == "\\"
      and quote ~= "'"
      and (
        next_char == "\\"
        or next_char == '"'
        or next_char == "'"
        or next_char == " "
      )
    then
      current = current .. next_char
      i = i + 1
    elseif quote and char == quote then
      quote = nil
    elseif not quote and (char == "'" or char == '"') then
      quote = char
    elseif not quote and char:match("%s") then
      if current ~= "" then
        table.insert(result, current)
        current = ""
      end
    else
      current = current .. char
    end
    i = i + 1
  end
  if current ~= "" then
    table.insert(result, current)
  end
  return result
end

local function selected_project()
  local selected = workspace.current().project
  if not selected or vim.fn.filereadable(selected) ~= 1 then
    return nil, "Select a .NET startup project in Dotnet Manager first"
  end
  return selected
end

local function selected_profile(project)
  local name = workspace.current().profile
  if not name then
    return nil
  end
  for _, profile in ipairs(launch.profiles(project)) do
    if profile.name == name then
      return profile
    end
  end
  return nil
end

M.build_cmd = function(project, configuration, tfm)
  local cmd = { "dotnet", "build", project, "-c", configuration or "Debug" }
  if tfm then
    vim.list_extend(cmd, { "-f", tfm })
  end
  return cmd
end

M.config = function()
  local project, err = selected_project()
  if not project then
    return nil, err
  end
  local selected = workspace.current()
  local metadata, query_err =
    msbuild.get(project, selected.configuration, selected.tfm)
  if not metadata then
    return nil, query_err
  end
  if metadata.OutputType == "Library" then
    return nil, "A class library cannot be launched directly"
  end
  local profile = selected_profile(project)
  local env = vim.deepcopy(profile and profile.environmentVariables or {})
  if profile and profile.applicationUrl and not env.ASPNETCORE_URLS then
    env.ASPNETCORE_URLS = profile.applicationUrl
  end
  return {
    type = adapter_type,
    request = "launch",
    name = "Dotnet: Launch " .. vim.fn.fnamemodify(project, ":t:r"),
    program = metadata.TargetPath,
    cwd = profile and profile.workingDirectory or vim.fs.dirname(project),
    args = profile and profile.commandLineArgs and split_arguments(
      profile.commandLineArgs
    ) or {},
    env = env,
    dotnet_project = project,
    dotnet_configuration = selected.configuration,
    dotnet_tfm = selected.tfm,
    justMyCode = false,
    stopAtEntry = false,
  }
end

local function adapter_path(opts)
  local configured = opts and opts.adapter_path
  if configured and configured ~= "" then
    return configured
  end
  local path = vim.fn.exepath("netcoredbg")
  return path ~= "" and path or nil
end

M.setup = function(opts)
  opts = opts or {}
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false, "nvim-dap is not installed"
  end
  local executable = adapter_path(opts)
  if not executable or vim.fn.executable(executable) ~= 1 then
    return false, "netcoredbg is unavailable; install it or set adapter_path"
  end

  dap.adapters[adapter_type] = function(callback, config)
    local adapter = {
      type = "executable",
      command = executable,
      args = { "--interpreter=vscode" },
    }
    if config.request == "attach" then
      callback(adapter)
      return
    end
    local project = config.dotnet_project
    if not project then
      vim.notify("No .NET startup project selected", vim.log.levels.ERROR)
      return
    end
    local root = workspace.current().root
    job.run(
      M.build_cmd(project, config.dotnet_configuration, config.dotnet_tfm),
      nil,
      nil,
      {
        cwd = root,
        on_exit = function(code)
          vim.schedule(function()
            if code == 0 then
              callback(adapter)
            else
              vim.notify(
                ".NET build failed; debugger was not started",
                vim.log.levels.ERROR
              )
            end
          end)
        end,
      }
    )
  end

  dap.configurations.cs = dap.configurations.cs or {}
  for i = #dap.configurations.cs, 1, -1 do
    if dap.configurations.cs[i].dotnet_cli_owned then
      table.remove(dap.configurations.cs, i)
    end
  end
  table.insert(dap.configurations.cs, {
    type = adapter_type,
    name = "Dotnet: Launch selected project",
    request = "launch",
    dotnet_cli_owned = true,
    program = function()
      local config, err = M.config()
      if not config then
        vim.notify(err, vim.log.levels.ERROR)
        return dap.ABORT
      end
      return config.program
    end,
    cwd = function()
      local config = M.config()
      return config and config.cwd or dap.ABORT
    end,
    env = function()
      local config = M.config()
      return config and config.env or {}
    end,
    args = function()
      local config = M.config()
      return config and config.args or {}
    end,
    dotnet_project = function()
      return workspace.current().project
    end,
    dotnet_configuration = function()
      return workspace.current().configuration
    end,
    dotnet_tfm = function()
      return workspace.current().tfm
    end,
  })
  table.insert(dap.configurations.cs, {
    type = adapter_type,
    name = "Dotnet: Attach to process",
    request = "attach",
    processId = require("dap.utils").pick_process,
    dotnet_cli_owned = true,
  })
  return true
end

M.launch = function()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false, "nvim-dap is not installed"
  end
  if not dap.adapters[adapter_type] then
    local setup_ok, err = M.setup()
    if not setup_ok then
      return false, err
    end
  end
  local config, err = M.config()
  if not config then
    return false, err
  end
  dap.run(config)
  return true
end

M.attach = function()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false, "nvim-dap is not installed"
  end
  if not dap.adapters[adapter_type] then
    local setup_ok, err = M.setup()
    if not setup_ok then
      return false, err
    end
  end
  dap.run({
    type = adapter_type,
    name = "Dotnet: Attach to process",
    request = "attach",
    processId = require("dap.utils").pick_process,
  })
  return true
end

return M
