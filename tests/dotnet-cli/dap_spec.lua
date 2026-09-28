local workspace = require("dotnet-cli.workspace")
local msbuild = require("dotnet-cli.msbuild")
local launch = require("dotnet-cli.launch")
local dotnet_dap = require("dotnet-cli.dap")

describe(".NET DAP integration", function()
  local original_get, original_profiles, original_dap, original_utils
  local temp

  before_each(function()
    temp = vim.fn.tempname()
    vim.fn.mkdir(temp, "p")
    vim.fn.writefile({}, vim.fs.joinpath(temp, "App.csproj"))
    workspace.reset()
    workspace.select_project(vim.fs.joinpath(temp, "App.csproj"))
    original_get = msbuild.get
    original_profiles = launch.profiles
    original_dap = package.loaded.dap
    original_utils = package.loaded["dap.utils"]
  end)

  after_each(function()
    msbuild.get = original_get
    launch.profiles = original_profiles
    package.loaded.dap = original_dap
    package.loaded["dap.utils"] = original_utils
    workspace.reset()
    vim.fn.delete(temp, "rf")
  end)

  it("uses evaluated output and the selected Project launch profile", function()
    msbuild.get = function()
      return { TargetPath = vim.fs.joinpath(temp, "bin", "App.dll"), OutputType = "Exe" }
    end
    launch.profiles = function()
      return { {
        name = "Development",
        workingDirectory = temp,
        commandLineArgs = '--port 1234 "C:\\tmp\\input.txt"',
        environmentVariables = { ASPNETCORE_ENVIRONMENT = "Development" },
        applicationUrl = "https://localhost:1234",
      } }
    end
    workspace.set({ profile = "Development", tfm = "net10.0" })
    local config = assert(dotnet_dap.config())
    assert.are.equal(vim.fs.joinpath(temp, "bin", "App.dll"), config.program)
    assert.are.same({ "--port", "1234", "C:\\tmp\\input.txt" }, config.args)
    assert.are.equal("Development", config.env.ASPNETCORE_ENVIRONMENT)
    assert.are.equal("https://localhost:1234", config.env.ASPNETCORE_URLS)
    assert.are.same({ "dotnet", "build", vim.fs.joinpath(temp, "App.csproj"), "-c", "Debug", "-f", "net10.0" }, dotnet_dap.build_cmd(vim.fs.joinpath(temp, "App.csproj"), "Debug", "net10.0"))
  end)

  it("registers launch and attach without replacing unrelated configurations", function()
    local dap = {
      adapters = {},
      configurations = { cs = { { type = "other", name = "Custom" } } },
    }
    package.loaded.dap = dap
    package.loaded["dap.utils"] = { pick_process = function() return 1 end }
    assert.is_true(dotnet_dap.setup({ adapter_path = vim.v.progpath }))
    assert.is_function(dap.adapters.coreclr)
    assert.are.equal("Custom", dap.configurations.cs[1].name)
    assert.are.equal("Dotnet: Launch selected project", dap.configurations.cs[2].name)
    assert.are.equal("Dotnet: Attach to process", dap.configurations.cs[3].name)
  end)
end)
