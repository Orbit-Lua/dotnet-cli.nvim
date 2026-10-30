local workspace = require("dotnet-cli.workspace")
local storage = require("dotnet-cli.state")

describe("workspace selection persistence", function()
  local root, rename, notify
  before_each(function()
    root = vim.fs.normalize(vim.g.dotnet_test_root .. "/state-workspace")
    vim.fn.mkdir(root, "p")
    vim.fn.writefile({}, root .. "/App.sln")
    vim.fn.writefile({}, root .. "/App.csproj")
    rename, notify = vim.uv.fs_rename, vim.notify
  end)
  after_each(function()
    vim.uv.fs_rename, vim.notify = rename, notify
    workspace.reset()
    vim.fn.delete(root, "rf")
    vim.fn.delete(vim.fn.stdpath("state") .. "/dotnet-cli", "rf")
  end)

  it("restores selection fields after unloading the workspace owner", function()
    workspace.select_project(root .. "/App.csproj")
    workspace.set({
      configuration = "Release",
      tfm = "net10.0",
      profile = "Development",
    })
    workspace.reset()
    local restored = workspace.activate(root)
    assert.equals(root .. "/App.csproj", restored.project)
    assert.equals("Release", restored.configuration)
    assert.equals("net10.0", restored.tfm)
    assert.equals("Development", restored.profile)
    workspace.select_project(root .. "/Other.csproj")
    assert.is_nil(workspace.current().tfm)
    assert.is_nil(workspace.current().profile)
  end)

  it("keeps the last valid record when atomic replacement fails", function()
    workspace.select_project(root .. "/App.csproj")
    local warnings = {}
    vim.notify = function(message)
      warnings[#warnings + 1] = message
    end
    vim.uv.fs_rename = function()
      return nil, "injected replacement failure"
    end
    workspace.set({ configuration = "Release" })
    vim.uv.fs_rename = rename
    workspace.reset()
    assert.equals("Debug", workspace.activate(root).configuration)
    assert.equals(1, #warnings)
  end)

  it("recovers malformed state only after explicit reselection", function()
    workspace.select_project(root .. "/App.csproj")
    local files = vim.fn.glob(
      vim.fn.stdpath("state") .. "/dotnet-cli/workspaces/*.json",
      false,
      true
    )
    assert.equals(1, #files)
    vim.fn.writefile({ "not json" }, files[1])
    workspace.reset()
    assert.is_string(workspace.activate(root).selection_error)
    workspace.select_project(root .. "/App.csproj")
    assert.is_nil(workspace.current().selection_error)
    assert.equals(root .. "/App.csproj", assert(storage.load(root)).project)
  end)
end)
