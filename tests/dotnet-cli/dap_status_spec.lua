local adapter = require("dotnet-cli.dap.adapter")
local job = require("dotnet-cli.job")
local startup = require("dotnet-cli.startup")

describe("debug launch status", function()
  local saved, dap, calls, root, project
  local returns_handle, build_code, build_output, session_starts

  before_each(function()
    saved = {
      dap = package.loaded.dap,
      utils = package.loaded["dap.utils"],
      notify = vim.notify,
      run = job.run,
      resolve = startup.resolve,
      restore = adapter.restore_console,
    }
    root = vim.fs.normalize(vim.g.dotnet_test_root)
    project = root .. "/App.csproj"
    calls, returns_handle, build_code, build_output = {}, true, 0, {}
    session_starts = true
    vim.notify = function(message, level, opts)
      calls[#calls + 1] = { message = message, level = level, opts = opts }
      return returns_handle and { handle = #calls } or nil
    end
    -- startup.resolve always delivers its result on a later event loop turn.
    startup.resolve = function(callback)
      vim.schedule(function()
        callback({ root = root, project = project, configuration = "Debug" }, {
          TargetPath = root .. "/bin/App.dll",
          OutputType = "Exe",
          IsTestProject = false,
        })
      end)
    end
    job.run = function(_, _, _, opts)
      opts.on_stderr(1, build_output)
      opts.on_exit(build_code)
      return 1
    end
    local sessions = 0
    dap = {
      ABORT = {},
      adapters = {},
      configurations = {},
      listeners = { on_config = {}, on_session = {}, after = {} },
    }
    -- Start the adapter as nvim-dap does: the session exists when the
    -- adapter callback returns, or the spawn failed.
    dap.run = function(config)
      dap.adapters.coreclr(function()
        if session_starts then
          sessions = sessions + 1
          dap.session = { id = sessions, config = config }
          dap.listeners.on_session["dotnet-cli"](nil, dap.session)
        end
      end, config)
    end
    package.loaded.dap = dap
    package.loaded["dap.utils"] = { pick_process = function() end }
    assert.is_true(
      require("dotnet-cli.dap").setup({ adapter_path = vim.v.progpath })
    )
  end)

  after_each(function()
    package.loaded.dap = saved.dap
    package.loaded["dap.utils"] = saved.utils
    vim.notify, job.run = saved.notify, saved.run
    startup.resolve = saved.resolve
    adapter.restore_console = saved.restore
  end)

  ---@param count integer
  local function wait_calls(count)
    assert.is_true(vim.wait(1000, function()
      return #calls >= count
    end, 10))
  end

  local function messages()
    local result = {}
    for _, call in ipairs(calls) do
      result[#result + 1] = call.message
    end
    return result
  end

  local function finish_session(exit_code)
    local session = dap.session
    dap.listeners.after.launch["dotnet-cli"](session, nil, {}, {})
    dap.listeners.after.event_exited["dotnet-cli"](session, {
      exitCode = exit_code,
    })
    session.closed = true
    dap.listeners.after.event_terminated["dotnet-cli"](session, {})
    dap.listeners.on_session["dotnet-cli"](session, nil)
  end

  it("moves one notification through every phase of a launch", function()
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(3)
    finish_session(0)
    assert.same({
      "Resolving the startup project",
      "Building App",
      "Starting netcoredbg",
      "Debugging App",
      "App exited with code 0",
    }, messages())
    for index, call in ipairs(calls) do
      assert.equals("Dotnet", call.opts.title)
      assert.equals(vim.log.levels.INFO, call.level)
      if index == 1 then
        assert.is_nil(call.opts.replace)
      else
        assert.same({ handle = index - 1 }, call.opts.replace)
      end
      if index == 2 or index == 3 then
        assert.is_false(call.opts.timeout)
      else
        assert.is_nil(call.opts.timeout)
      end
    end
  end)

  it("carries the resolve phase of the registered launch configuration", function()
    local resolved
    local thread = coroutine.create(function()
      resolved = dap.listeners.on_config["dotnet-cli"](dap.configurations.cs[1])
    end)
    assert(coroutine.resume(thread))
    assert.is_true(vim.wait(1000, function()
      return resolved ~= nil
    end))
    dap.run(resolved)
    wait_calls(3)
    finish_session(3)
    assert.equals(5, #calls)
    assert.equals("App exited with code 3", calls[5].message)
    assert.equals(vim.log.levels.WARN, calls[5].level)
    assert.same({ handle = 4 }, calls[5].opts.replace)
  end)

  it("ends on a failed resolve", function()
    startup.resolve = function(callback)
      vim.schedule(function()
        callback(nil, nil, "No runnable non-test .NET project found")
      end)
    end
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(2)
    assert.equals(2, #calls)
    assert.equals("No runnable non-test .NET project found", calls[2].message)
    assert.equals(vim.log.levels.WARN, calls[2].level)
    assert.same({ handle = 1 }, calls[2].opts.replace)
    assert.is_nil(calls[2].opts.timeout)
  end)

  it("ends on a failed build with the compiler errors", function()
    local error_line =
      "C:\\src\\App\\Program.cs(3,5): error CS1002: ; expected [C:\\src\\App\\App.csproj]"
    build_code, build_output = 1, {
      error_line,
      error_line,
      "C:\\src\\App\\Program.cs(9,1): error CS0103: The name 'x' does not exist [C:\\src\\App\\App.csproj]",
      "C:\\src\\App\\Program.cs(2,1): warning CS0168: unused [C:\\src\\App\\App.csproj]",
    }
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(3)
    local last = calls[3]
    assert.equals(3, #calls)
    assert.equals(vim.log.levels.ERROR, last.level)
    assert.same({ handle = 2 }, last.opts.replace)
    assert.equals(
      table.concat({
        ".NET build failed: 2 errors",
        "Program.cs(3,5): CS1002: ; expected",
        "Program.cs(9,1): CS0103: The name 'x' does not exist",
      }, "\n"),
      last.message
    )
  end)

  it("ends on the last output lines when no compiler error parses", function()
    build_code, build_output = 1, { "MSBUILD : error MSB1009: Project file does not exist." }
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(3)
    assert.equals(
      ".NET build failed\nMSBUILD : error MSB1009: Project file does not exist.",
      calls[3].message
    )
  end)

  it("ends when the debug adapter does not start", function()
    session_starts = false
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(4)
    assert.equals("Debugger did not start", calls[4].message)
    assert.equals(vim.log.levels.ERROR, calls[4].level)
    assert.same({ handle = 3 }, calls[4].opts.replace)
  end)

  it("ends when the launch request fails", function()
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(3)
    dap.listeners.after.launch["dotnet-cli"](dap.session, { message = "no program" })
    dap.listeners.after.event_terminated["dotnet-cli"](dap.session, {})
    assert.equals(4, #calls)
    assert.equals("Debugger launch failed: no program", calls[4].message)
    assert.equals(vim.log.levels.ERROR, calls[4].level)
  end)

  it("shows each phase as its own message when the notifier returns nothing", function()
    returns_handle = false
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(3)
    finish_session(0)
    assert.equals(5, #calls)
    for _, call in ipairs(calls) do
      assert.equals("Dotnet", call.opts.title)
      assert.is_nil(call.opts.replace)
    end
  end)

  it("keeps the console restore in the session listener", function()
    local restored = 0
    adapter.restore_console = function()
      restored = restored + 1
    end
    assert.is_true(require("dotnet-cli.dap").launch())
    wait_calls(3)
    finish_session(0)
    assert.equals(2, restored)
  end)
end)
