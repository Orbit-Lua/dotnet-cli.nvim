local workspace = require("dotnet-cli.workspace")
local msbuild = require("dotnet-cli.msbuild")
local startup = require("dotnet-cli.startup")

describe("startup project resolution", function()
  local root, saved, metadata, launches, messages, pending
  before_each(function()
    root = vim.fs.normalize(vim.g.dotnet_test_root .. "/workspace")
    vim.fn.mkdir(root, "p")
    vim.fn.writefile({}, root .. "/App.sln")
    for _, name in ipairs({ "App", "Library", "Tests" }) do
      vim.fn.writefile({}, root .. "/" .. name .. ".csproj")
    end
    saved = {
      cwd = vim.fn.getcwd(),
      get = msbuild.get_async,
      dap = package.loaded.dap,
      utils = package.loaded["dap.utils"],
      notify = vim.notify,
      select = vim.ui.select,
    }
    vim.fn.chdir(root)
    workspace.reset()
    metadata = {
      App = {
        OutputType = "Exe",
        TargetFramework = "net10.0",
        TargetPath = root .. "/custom/App.dll",
      },
      Library = {
        OutputType = "Library",
        TargetFramework = "net10.0",
        TargetPath = root .. "/Library.dll",
      },
      Tests = {
        OutputType = "Exe",
        IsTestProject = true,
        TargetFramework = "net10.0",
        TargetPath = root .. "/Tests.dll",
      },
    }
    launches, messages, pending = {}, {}, {}
    vim.notify = function(message)
      messages[#messages + 1] = message
    end
    vim.ui.select = function()
      error("Unambiguous applications must not prompt")
    end
    msbuild.get_async = function(path, _, _, _, callback)
      local name = vim.fn.fnamemodify(path, ":t:r")
      vim.schedule(function()
        callback(vim.deepcopy(metadata[name]))
      end)
    end
    package.loaded.dap = {
      adapters = {},
      configurations = {},
      run = function(config)
        launches[#launches + 1] = config
      end,
    }
    package.loaded["dap.utils"] = { pick_process = function() end }
    assert.is_true(
      require("dotnet-cli.dap").setup({ adapter_path = vim.v.progpath })
    )
    require("dotnet-cli.commands.register").setup("Dotnet")
  end)
  after_each(function()
    package.loaded["dotnet-cli.workspace"] = workspace
    msbuild.get_async, vim.notify, vim.ui.select =
      saved.get, saved.notify, saved.select
    package.loaded.dap, package.loaded["dap.utils"] = saved.dap, saved.utils
    vim.fn.chdir(saved.cwd)
    workspace.reset()
    vim.fn.delete(root, "rf")
    vim.fn.delete(vim.fn.stdpath("state") .. "/dotnet-cli", "rf")
  end)
  local function wait_for_result()
    assert.is_true(vim.wait(1000, function()
      return #launches + #messages > 0
    end, 10))
  end

  it(
    "launches the unique application through DotnetDebug without picking a csproj",
    function()
      vim.cmd("DotnetDebug")
      wait_for_result()
      assert.equals(1, #launches)
      assert.equals(root .. "/App.csproj", launches[1].dotnet_project)
      assert.equals(root .. "/custom/App.dll", launches[1].program)
      vim.cmd("DotnetDebug")
      assert.is_true(vim.wait(1000, function()
        return #launches == 2
      end))
      assert.equals(root .. "/App.csproj", launches[2].dotnet_project)
    end
  )

  it(
    "resolves the registered DAP configuration through its public configuration hook",
    function()
      local dap = package.loaded.dap
      local resolved
      local co = coroutine.create(function()
        resolved =
          dap.listeners.on_config["dotnet-cli"](dap.configurations.cs[1])
      end)
      assert(coroutine.resume(co))
      assert.is_true(vim.wait(1000, function()
        return resolved ~= nil
      end))
      assert.equals(root .. "/App.csproj", resolved.dotnet_project)
      assert.equals(root .. "/custom/App.dll", resolved.program)
    end
  )

  it(
    "requires an explicit replacement for a missing restored selection",
    function()
      workspace.select_project(root .. "/Deleted.csproj")
      package.loaded["dotnet-cli.workspace"] = nil
      local reloaded = require("dotnet-cli.workspace")
      assert.equals(root .. "/Deleted.csproj", reloaded.activate(root).project)
      package.loaded["dotnet-cli.workspace"] = workspace
      workspace.reset()
      vim.cmd("DotnetDebug")
      wait_for_result()
      assert.equals(0, #launches)
      assert.is_truthy(messages[1]:find("missing", 1, true))
      workspace.select_project(root .. "/App.csproj")
      vim.cmd("DotnetDebug")
      assert.is_true(vim.wait(1000, function()
        return #launches == 1
      end))
    end
  )

  it("does not complete an obsolete workspace request", function()
    msbuild.get_async = function(_, _, _, _, callback)
      pending[#pending + 1] = callback
    end
    vim.cmd("DotnetDebug")
    assert.is_true(vim.wait(1000, function()
      return #pending > 0
    end))
    workspace.set({ root = root .. "/other" })
    pending[1](metadata.App)
    wait_for_result()
    assert.equals(0, #launches)
    assert.is_truthy(messages[1]:find("obsolete", 1, true))
  end)

  it("does not launch when an ambiguous picker is canceled", function()
    metadata.Library = vim.deepcopy(metadata.App)
    vim.ui.select = function(items, _, callback)
      assert.equals(2, #items)
      callback(nil)
    end
    vim.cmd("DotnetDebug")
    wait_for_result()
    assert.equals(0, #launches)
    assert.is_nil(workspace.current().project)
  end)

  it("does not restore an obsolete profile after metadata returns", function()
    workspace.select_project(root .. "/App.csproj", { profile = "First" })
    msbuild.get_async = function(_, _, _, _, callback)
      pending[#pending + 1] = callback
    end
    vim.cmd("DotnetDebug")
    assert.equals(1, #pending)
    workspace.set({ profile = "Second" })
    pending[1](metadata.App)
    wait_for_result()
    assert.equals(0, #launches)
    assert.equals("Second", workspace.current().profile)
    assert.is_truthy(messages[1]:find("obsolete", 1, true))
  end)

  it(
    "rejects configuration changes before scheduled startup delivery",
    function()
      msbuild.get_async = function(_, _, _, _, callback)
        callback(metadata.App)
      end
      vim.cmd("DotnetDebug")
      workspace.set({ configuration = "Release" })
      wait_for_result()
      assert.equals(0, #launches)
      assert.equals("Release", workspace.current().configuration)
      assert.is_truthy(messages[1]:find("obsolete", 1, true))
    end
  )
end)
