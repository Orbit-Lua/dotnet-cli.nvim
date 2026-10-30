local root = vim.fs.normalize(vim.g.dotnet_test_root .. "/debug project")
local cwd = vim.fn.getcwd()
local child
local dap = require("dap")
dap.set_log_level("DEBUG")
local console
if vim.fn.has("win32") == 1 then
  local ffi = require("ffi")
  pcall(ffi.cdef, "unsigned int GetConsoleOutputCP(void);")
  console = ffi.C
end
local code_page = console and console.GetConsoleOutputCP()
local ok, err = pcall(function()
  assert(vim.fn.executable("dotnet") == 1, "dotnet is required")
  vim.fn.mkdir(root, "p")
  vim.env.DOTNET_CLI_HOME = root .. "/cli"
  vim.env.DOTNET_NOLOGO = "1"
  vim.env.DOTNET_CLI_TELEMETRY_OPTOUT = "1"
  vim.fn.writefile({
    '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup>',
    "<OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework>",
    "<OutputPath>custom/</OutputPath>",
    "</PropertyGroup></Project>",
  }, root .. "/App.csproj")
  vim.fn.writefile({
    "using System;",
    "class Program",
    "{",
    "    static void Main()",
    "    {",
    '        Console.WriteLine("fixture ready 中文");',
    "        System.Threading.Thread.Sleep(300000);",
    "    }",
    "}",
  }, root .. "/Program.cs")
  vim.fn.chdir(root)
  local buffer = vim.fn.bufadd(root .. "/Program.cs")
  vim.fn.bufload(buffer)
  vim.api.nvim_set_current_buf(buffer)
  vim.bo[buffer].filetype = "cs"
  require("dotnet-cli.config").setup({
    output_dir_template = root .. "/overridden/{config}",
  })
  vim.env.MASON = vim.env.MASON
    or vim.fs.dirname(vim.g.dotnet_test_plugins) .. "/mason"
  assert(
    require("dotnet-cli").setup_dap({
      adapter_path = vim.env.DOTNET_TEST_ADAPTER,
    })
  )
  local messages = {}
  vim.notify = function(message, level)
    if level and level >= vim.log.levels.WARN then
      messages[#messages + 1] = message
    end
  end
  local stopped
  dap.listeners.after.event_stopped["native-test"] = function(session, body)
    stopped =
      { session = session, reason = body.reason, thread = body.threadId }
  end
  local output = ""
  dap.listeners.after.event_output["native-test"] = function(_, body)
    if body.category == "stdout" then
      output = output .. body.output
    end
  end
  require("dap.breakpoints").set({}, buffer, 6)
  vim.ui.select = function()
    error("One application must not request a project picker")
  end
  vim.cmd("runtime plugin/dap.lua")
  vim.cmd([[DapNew Dotnet:\ Launch\ selected\ project]])
  assert(
    vim.wait(30000, function()
      return stopped ~= nil or #messages > 0
    end, 20),
    "debug launch timed out"
  )
  assert(stopped, table.concat(messages, "\n"))
  assert(stopped.reason == "breakpoint", "expected a source breakpoint")
  local config = stopped.session.config
  assert(
    vim.fs.normalize(config.program) == root .. "/overridden/Debug/App.dll",
    "output override and debugger target differ"
  )
  -- The integrated console must carry debuggee stdout through DAP; a
  -- detached Windows adapter shows it in a separate console window instead.
  stopped.session:request(
    "continue",
    { threadId = stopped.thread },
    function() end
  )
  assert(
    vim.wait(10000, function()
      return output:find("fixture ready", 1, true) ~= nil
    end),
    "debuggee stdout did not reach the DAP console"
  )
  assert(
    output:find("fixture ready 中文", 1, true),
    "debuggee stdout is not UTF-8: " .. output
  )
  local disconnected = false
  stopped.session:disconnect({ terminateDebuggee = true }, function()
    disconnected = true
  end)
  assert(
    vim.wait(5000, function()
      return disconnected
    end),
    "disconnect timed out"
  )
  local ready = false
  child = vim.system({ "dotnet", config.program }, {
    cwd = root,
    stdout = function(_, data)
      if data and data:find("fixture ready", 1, true) then
        ready = true
      end
    end,
  })
  assert(
    vim.wait(5000, function()
      return ready
    end),
    "attach fixture did not start"
  )
  stopped = nil
  dap.run({
    type = "coreclr",
    name = "Fixture attach",
    request = "attach",
    processId = child.pid,
  })
  assert(
    vim.wait(10000, function()
      return dap.session() and dap.session().initialized
    end),
    "attach did not initialize"
  )
  local attached = dap.session()
  local threads
  attached:request("threads", {}, function(thread_err, body)
    assert(not thread_err, tostring(thread_err))
    threads = body.threads
  end)
  assert(
    vim.wait(5000, function()
      return threads and #threads > 0
    end),
    "attached threads missing"
  )
  local paused = false
  attached:request("pause", { threadId = threads[1].id }, function(pause_err)
    paused = not pause_err
  end)
  assert(
    vim.wait(5000, function()
      return paused and stopped ~= nil
    end),
    "attached process did not pause"
  )
  disconnected = false
  attached:disconnect({ terminateDebuggee = true }, function()
    disconnected = true
  end)
  assert(
    vim.wait(5000, function()
      return disconnected
    end),
    "attach disconnect timed out"
  )
  assert(
    vim.wait(5000, function()
      return next(dap.sessions()) == nil
    end),
    "debug sessions did not close"
  )
  assert(
    not console or console.GetConsoleOutputCP() == code_page,
    "console code page was not restored"
  )
  print(
    "Native DapNew launch, output override, source breakpoint, console output, attach, pause, and disconnect passed"
  )
end)
if dap.session() then
  dap.session():close()
end
if child then
  child:kill(9)
  child:wait(5000)
end
vim.fn.chdir(cwd)
if not ok then
  for _, path in
    ipairs(vim.fn.glob(vim.fn.stdpath("cache") .. "/dap*.log", false, true))
  do
    io.stderr:write(table.concat(vim.fn.readfile(path), "\n") .. "\n")
  end
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
