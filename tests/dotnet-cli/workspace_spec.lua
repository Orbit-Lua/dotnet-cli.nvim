local workspace = require("dotnet-cli.workspace")

describe("workspace", function()
  local tmp

  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(vim.fs.joinpath(tmp, "src", "A"), "p")
    vim.fn.mkdir(vim.fs.joinpath(tmp, "src", "B"), "p")
    vim.fn.writefile({}, vim.fs.joinpath(tmp, "App.sln"))
    vim.fn.writefile({}, vim.fs.joinpath(tmp, "src", "A", "A.csproj"))
    vim.fn.writefile({}, vim.fs.joinpath(tmp, "src", "B", "B.csproj"))
    workspace.reset()
  end)

  after_each(function()
    workspace.reset()
    vim.fn.delete(tmp, "rf")
  end)

  it("selects a project and discovers its solution root", function()
    local selected =
      workspace.select_project(vim.fs.joinpath(tmp, "src", "A", "A.csproj"))
    assert.are.equal(vim.fs.normalize(tmp), selected.root)
    assert.are.equal(
      vim.fs.normalize(vim.fs.joinpath(tmp, "App.sln")),
      selected.solution
    )
    assert.are.equal(
      vim.fs.normalize(vim.fs.joinpath(tmp, "src", "A", "A.csproj")),
      selected.project
    )
    assert.are.equal("Debug", selected.configuration)
  end)

  it("keeps project and configuration choices isolated by root", function()
    local a_root = vim.fs.joinpath(tmp, "src", "A")
    local b_root = vim.fs.joinpath(tmp, "src", "B")
    workspace.set({ root = a_root })
    workspace.set({
      project = vim.fs.joinpath(a_root, "A.csproj"),
      configuration = "Release",
      profile = "A",
    })
    workspace.set({ root = b_root })
    workspace.set({
      project = vim.fs.joinpath(b_root, "B.csproj"),
      tfm = "net8.0",
    })
    local b = workspace.current()
    assert.are.equal("net8.0", b.tfm)
    workspace.set({ root = a_root })
    local a = workspace.current()
    assert.are.equal("Release", a.configuration)
    assert.are.equal("A", a.profile)
    assert.is_nil(a.tfm)
  end)

  it("reactivates the discovered solution without losing its selection", function()
    local a = vim.fs.joinpath(tmp, "src", "A", "A.csproj")
    workspace.select_project(a)
    workspace.set({ configuration = "Release" })
    workspace.set({ root = vim.fs.joinpath(tmp, "src", "B") })
    local active = workspace.activate(vim.fs.joinpath(tmp, "src", "A"))
    assert.are.equal(vim.fs.normalize(tmp), active.root)
    assert.are.equal(vim.fs.normalize(a), active.project)
    assert.are.equal("Release", active.configuration)
  end)
end)
