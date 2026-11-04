-- The netcoredbg executable and the coreclr adapter that builds before launch.
local build = require("dotnet-cli.build")
local job = require("dotnet-cli.job")
local settings = require("dotnet-cli.config")
local workspace = require("dotnet-cli.workspace")

local M = {}

M.type = "coreclr"

local utf8_code_page = 65001

-- Code page to restore after the last .NET session, if this module changed it.
local saved_code_page

local function console_api()
  if vim.fn.has("win32") ~= 1 then
    return nil
  end
  local ok, ffi = pcall(require, "ffi")
  if not ok then
    return nil
  end
  -- Another plugin may have declared these already.
  pcall(
    ffi.cdef,
    "unsigned int GetConsoleOutputCP(void); int SetConsoleOutputCP(unsigned int);"
  )
  return ffi.C
end

-- The integrated debuggee shares Neovim's console and encodes stdout with its
-- output code page. netcoredbg forwards those bytes unchanged, while nvim-dap
-- reads UTF-8, so switch the console to UTF-8 for the session.
local function use_utf8_console()
  local api = console_api()
  if not api or saved_code_page then
    return
  end
  local current = api.GetConsoleOutputCP()
  if current == 0 or current == utf8_code_page then
    return
  end
  if api.SetConsoleOutputCP(utf8_code_page) ~= 0 then
    saved_code_page = current
  end
end

---Restore the console code page once no coreclr session remains.
---@param dap? table the nvim-dap module
function M.restore_console(dap)
  if not saved_code_page then
    return
  end
  for _, session in pairs(dap and dap.sessions and dap.sessions() or {}) do
    if session.config and session.config.type == M.type then
      return
    end
  end
  local api = console_api()
  if api then
    api.SetConsoleOutputCP(saved_code_page)
  end
  saved_code_page = nil
end

-- Mason's batch shim cannot carry the DAP stdio transport reliably, so find
-- the native executable in the Mason package.
---@return string?
local function mason_native()
  local shim = vim.fn.exepath("netcoredbg")
  local root = vim.env.MASON
  if not root and shim ~= "" then
    root = vim.fs.dirname(vim.fs.dirname(shim))
  end
  if not root then
    return nil
  end
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

---@param configured? string
---@return string?
local function find(configured)
  if configured and configured ~= "" then
    return configured
  end
  local windows = vim.fn.has("win32") == 1
  local path = vim.fn.exepath(windows and "netcoredbg.exe" or "netcoredbg")
  if path ~= "" then
    return path
  end
  if windows then
    return mason_native()
  end
end

---Find a native netcoredbg executable.
---@param configured? string explicit `adapter_path`
---@return string? executable
---@return string? err
function M.executable(configured)
  local executable = find(configured)
  if not executable or vim.fn.executable(executable) ~= 1 then
    return nil, "netcoredbg is unavailable; install it or set adapter_path"
  end
  local lower = executable:lower()
  if lower:match("%.cmd$") or lower:match("%.bat$") then
    return nil,
      "netcoredbg requires a native executable; set adapter_path to netcoredbg.exe"
  end
  return executable
end

---Build the project of a launch configuration.
---@param config DotnetCliLaunchConfig
---@param done fun(code: integer, output: string[])
---@return boolean started
local function build_project(config, done)
  local root = config.dotnet_root or workspace.current().root
  local output = {}
  local function collect(_, lines)
    for _, line in ipairs(lines) do
      if line ~= "" then
        output[#output + 1] = line
      end
    end
  end
  local argv = build.argv(
    config.dotnet_project,
    config.dotnet_configuration,
    config.dotnet_tfm,
    root
  )
  local id = job.run(argv, nil, nil, {
    cwd = root,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = collect,
    on_stderr = collect,
    on_exit = function(code)
      vim.schedule(function()
        done(code, output)
      end)
    end,
  })
  return id ~= nil and id > 0
end

---Create the coreclr adapter function. A launch builds the project first and
---starts netcoredbg only after a successful build.
---@param executable string
---@return fun(callback: fun(adapter: dap.Adapter), config: DotnetCliLaunchConfig)
function M.new(executable)
  return function(callback, config)
    local adapter = {
      type = "executable",
      command = executable,
      args = { "--interpreter=vscode" },
      -- A detached adapter has no console on Windows, so Windows opens a
      -- window for the debuggee. Attached, the debuggee shares Neovim's
      -- console and netcoredbg forwards its stdio as DAP output events.
      options = {
        detached = not settings.get().dap.integrated_console,
      },
    }
    if config.request == "attach" then
      callback(adapter)
      return
    end
    if not config.dotnet_project then
      vim.notify("No .NET startup project selected", vim.log.levels.ERROR)
      return
    end

    local started = build_project(config, function(code, output)
      if code ~= 0 then
        vim.notify(
          ".NET build failed; debugger was not started\n"
            .. table.concat(output, "\n"),
          vim.log.levels.ERROR
        )
        return
      end
      if not adapter.options.detached then
        use_utf8_console()
      end
      callback(adapter)
    end)
    if not started then
      vim.notify(
        "Could not start the .NET build; check the dotnet executable",
        vim.log.levels.ERROR
      )
    end
  end
end

return M
