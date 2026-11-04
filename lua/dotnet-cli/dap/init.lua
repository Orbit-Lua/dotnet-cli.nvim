-- Optional nvim-dap registration for netcoredbg.
local adapter = require("dotnet-cli.dap.adapter")
local launch_config = require("dotnet-cli.dap.config")

local M = {}

---@class DotnetCliDapOptions
---@field adapter_path? string Absolute path to a native netcoredbg executable.

M.build_cmd = require("dotnet-cli.build").argv
M.config = launch_config.launch

local listener = "dotnet-cli"

---Resolve the startup project from inside the nvim-dap `on_config` coroutine.
---@param dap table the nvim-dap module
---@param config dap.Configuration
---@return dap.Configuration
local function resolve_launch(dap, config)
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

---@param dap table the nvim-dap module
local function install_listeners(dap)
  dap.listeners = dap.listeners or {}
  dap.listeners.on_session = dap.listeners.on_session or {}
  dap.listeners.on_session[listener] = function()
    adapter.restore_console(dap)
  end
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("DotnetCliDap", { clear = true }),
    callback = function()
      adapter.restore_console()
    end,
  })
  dap.listeners.on_config = dap.listeners.on_config or {}
  dap.listeners.on_config[listener] = function(config)
    if not config.dotnet_cli_owned or config.request ~= "launch" then
      return config
    end
    return resolve_launch(dap, config)
  end
end

---Replace the configurations that an earlier setup registered.
---@param dap table the nvim-dap module
local function register_configurations(dap)
  dap.configurations.cs = dap.configurations.cs or {}
  local configurations = dap.configurations.cs
  for i = #configurations, 1, -1 do
    if configurations[i].dotnet_cli_owned then
      table.remove(configurations, i)
    end
  end
  table.insert(configurations, {
    type = adapter.type,
    name = "Dotnet: Launch selected project",
    request = "launch",
    dotnet_cli_owned = true,
  })
  table.insert(configurations, {
    type = adapter.type,
    name = "Dotnet: Attach to process",
    request = "attach",
    processId = require("dap.utils").pick_process,
    dotnet_cli_owned = true,
  })
end

---Register the coreclr adapter, its listeners and the cs configurations.
---@param opts? DotnetCliDapOptions
---@return boolean ok
---@return string? err
function M.setup(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    return false, "setup_dap options: expected table, got " .. type(opts)
  end
  for key, value in pairs(opts) do
    if key ~= "adapter_path" then
      return false, tostring(key) .. ": unknown option"
    end
    if type(value) ~= "string" then
      return false, "adapter_path: expected string, got " .. type(value)
    end
  end
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false, "nvim-dap is not installed"
  end
  local executable, err = adapter.executable(opts.adapter_path)
  if not executable then
    return false, err
  end

  dap.adapters[adapter.type] = adapter.new(executable)
  install_listeners(dap)
  register_configurations(dap)
  return true
end

---@return table? dap
---@return string? err
local function ready_dap()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return nil, "nvim-dap is not installed"
  end
  if not dap.adapters[adapter.type] then
    local setup_ok, err = M.setup()
    if not setup_ok then
      return nil, err
    end
  end
  return dap
end

---Resolve the startup project, then build and debug it.
---@return boolean ok
---@return string? err
function M.launch()
  local dap, err = ready_dap()
  if not dap then
    return false, err
  end
  require("dotnet-cli.startup").resolve(function(context, metadata, resolve_err)
    if not context then
      vim.notify(resolve_err, vim.log.levels.WARN, { title = "Dotnet" })
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

---Attach the debugger to a picked process.
---@return boolean ok
---@return string? err
function M.attach()
  local dap, err = ready_dap()
  if not dap then
    return false, err
  end
  dap.run({
    type = adapter.type,
    name = "Dotnet: Attach to process",
    request = "attach",
    processId = require("dap.utils").pick_process,
  })
  return true
end

return M
