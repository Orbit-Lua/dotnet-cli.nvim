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

local function selected_profile(project, selected)
  local name = selected.profile
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

M.build_cmd = require("dotnet-cli.build").argv

M.config = function(context, evaluated)
  local project, err
  if context then
    project = context.project
  else
    project, err = selected_project()
  end
  if not project then
    return nil, err
  end
  local selected = context or workspace.current()
  local metadata, query_err = evaluated, nil
  if not metadata then
    metadata, query_err =
      msbuild.get(project, selected.configuration, selected.tfm, selected.root)
  end
  if not metadata then
    return nil, query_err
  end
  if metadata.OutputType == "Library" or metadata.IsTestProject then
    return nil, "A class library cannot be launched directly"
  end
  local profile = selected_profile(project, selected)
  if selected.profile and not profile then
    return nil,
      "The selected launch profile is unavailable; select a profile in Dotnet Manager"
  end
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
    dotnet_root = selected.root,
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
  local windows = vim.fn.has("win32") == 1
  local path = vim.fn.exepath(windows and "netcoredbg.exe" or "netcoredbg")
  if path ~= "" then
    return path
  end
  if windows then
    -- Mason's batch shim cannot carry the DAP stdio transport reliably.
    local shim = vim.fn.exepath("netcoredbg")
    local root = vim.env.MASON
    if not root and shim ~= "" then
      root = vim.fs.dirname(vim.fs.dirname(shim))
    end
    if root then
      local native = vim.fs.joinpath(
        root,
        "packages",
        "netcoredbg",
        "netcoredbg",
        "netcoredbg.exe"
      )
      if vim.fn.executable(native) == 1 then
        return native
      end
    end
  end
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
  if
    executable:lower():match("%.cmd$") or executable:lower():match("%.bat$")
  then
    return false,
      "netcoredbg requires a native executable; set adapter_path to netcoredbg.exe"
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
    local root = config.dotnet_root or workspace.current().root
    local output = {}
    local function collect(_, lines)
      for _, line in ipairs(lines) do
        if line ~= "" then
          output[#output + 1] = line
        end
      end
    end
    local id = job.run(
      M.build_cmd(project, config.dotnet_configuration, config.dotnet_tfm, root),
      nil,
      nil,
      {
        cwd = root,
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = collect,
        on_stderr = collect,
        on_exit = function(code)
          vim.schedule(function()
            if code == 0 then
              callback(adapter)
            else
              vim.notify(
                ".NET build failed; debugger was not started\n"
                  .. table.concat(output, "\n"),
                vim.log.levels.ERROR
              )
            end
          end)
        end,
      }
    )
    if not id or id <= 0 then
      vim.notify(
        "Could not start the .NET build; check the dotnet executable",
        vim.log.levels.ERROR
      )
    end
  end

  dap.configurations.cs = dap.configurations.cs or {}
  for i = #dap.configurations.cs, 1, -1 do
    if dap.configurations.cs[i].dotnet_cli_owned then
      table.remove(dap.configurations.cs, i)
    end
  end
  dap.listeners = dap.listeners or {}
  dap.listeners.on_config = dap.listeners.on_config or {}
  dap.listeners.on_config["dotnet-cli"] = function(config)
    if not config.dotnet_cli_owned or config.request ~= "launch" then
      return config
    end
    local thread = coroutine.running()
    require("dotnet-cli.startup").resolve(function(context, metadata, err)
      coroutine.resume(thread, context, metadata, err)
    end)
    local context, metadata, err = coroutine.yield()
    if not context then
      vim.notify(err, vim.log.levels.WARN, { title = "Dotnet" })
      return vim.tbl_extend("force", config, { program = dap.ABORT })
    end
    local resolved, config_err = M.config(context, metadata)
    if not resolved then
      vim.notify(config_err, vim.log.levels.WARN, { title = "Dotnet" })
      return vim.tbl_extend("force", config, { program = dap.ABORT })
    end
    return vim.tbl_extend("force", config, resolved)
  end
  table.insert(dap.configurations.cs, {
    type = adapter_type,
    name = "Dotnet: Launch selected project",
    request = "launch",
    dotnet_cli_owned = true,
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
  require("dotnet-cli.startup").resolve(function(context, metadata, err)
    if not context then
      vim.notify(err, vim.log.levels.WARN, { title = "Dotnet" })
      return
    end
    local config, config_err = M.config(context, metadata)
    if not config then
      vim.notify(config_err, vim.log.levels.WARN, { title = "Dotnet" })
      return
    end
    dap.run(config)
  end)
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
