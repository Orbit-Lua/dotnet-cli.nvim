local owner = require("dotnet-cli.dap")
local job = require("dotnet-cli.job")

describe("debug adapter startup", function()
  local saved, dap, root
  before_each(function()
    saved = {
      dap = package.loaded.dap,
      utils = package.loaded["dap.utils"],
      path = vim.env.PATH,
      mason = vim.env.MASON,
      has = vim.fn.has,
      notify = vim.notify,
      run = job.run,
    }
    root = vim.fs.normalize(vim.g.dotnet_test_root .. "/mason with spaces")
    vim.fn.mkdir(root .. "/packages/netcoredbg/netcoredbg", "p")
    vim.fn.mkdir(root .. "/bin", "p")
    local native = root .. "/packages/netcoredbg/netcoredbg/netcoredbg.exe"
    vim.fn.writefile({ "fixture executable; never executed" }, native)
    assert(vim.uv.fs_chmod(native, 493))
    vim.fn.writefile({ "@echo off" }, root .. "/bin/netcoredbg.cmd")
    vim.env.PATH = root .. "/bin"
    vim.env.MASON = root
    vim.fn.has = function(name)
      return name == "win32" and 1 or saved.has(name)
    end
    dap = { adapters = {}, configurations = {} }
    package.loaded.dap = dap
    package.loaded["dap.utils"] = { pick_process = function() end }
  end)
  after_each(function()
    package.loaded.dap = saved.dap
    package.loaded["dap.utils"] = saved.utils
    vim.env.PATH, vim.env.MASON = saved.path, saved.mason
    vim.fn.has, vim.notify, job.run = saved.has, saved.notify, saved.run
    vim.fn.delete(root, "rf")
  end)

  it(
    "uses the native Mason executable instead of the batch transport",
    function()
      assert.is_true(owner.setup())
      local adapter
      dap.adapters.coreclr(function(value)
        adapter = value
      end, { request = "attach" })
      assert.equals(
        root .. "/packages/netcoredbg/netcoredbg/netcoredbg.exe",
        adapter.command
      )
      assert.same({ "--interpreter=vscode" }, adapter.args)
      assert.is_true(owner.setup())
      assert.equals(2, #dap.configurations.cs)
    end
  )

  it(
    "preserves explicit native paths and rejects an explicit batch wrapper",
    function()
      assert.is_true(owner.setup({ adapter_path = vim.v.progpath }))
      local adapter
      dap.adapters.coreclr(function(value)
        adapter = value
      end, { request = "attach" })
      assert.equals(vim.v.progpath, adapter.command)
      local ok, err =
        owner.setup({ adapter_path = root .. "/bin/netcoredbg.cmd" })
      assert.is_false(ok)
      assert.is_string(err)
    end
  )

  it("retains failed build output and never starts an adapter", function()
    assert.is_true(owner.setup({ adapter_path = vim.v.progpath }))
    local messages, called = {}, false
    vim.notify = function(message)
      messages[#messages + 1] = message
    end
    job.run = function(_, _, _, opts)
      assert.equals(root, opts.cwd)
      opts.on_stderr(1, { "error CS1002: ; expected", "" })
      opts.on_exit(1)
      return 1
    end
    dap.adapters.coreclr(function()
      called = true
    end, {
      request = "launch",
      dotnet_project = root .. "/App.csproj",
      dotnet_root = root,
    })
    assert.is_true(vim.wait(500, function()
      return #messages > 0
    end))
    assert.is_false(called)
    assert.is_truthy(messages[1]:find("CS1002", 1, true))
  end)

  it("reports failure to create the build process", function()
    assert.is_true(owner.setup({ adapter_path = vim.v.progpath }))
    local message
    vim.notify = function(value)
      message = value
    end
    job.run = function()
      return -1
    end
    dap.adapters.coreclr(function()
      error("adapter must not start")
    end, {
      request = "launch",
      dotnet_project = root .. "/App.csproj",
      dotnet_root = root,
    })
    assert.is_truthy(message:find("Could not start", 1, true))
  end)
end)
