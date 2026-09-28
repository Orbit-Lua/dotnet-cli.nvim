local packages = require("dotnet-cli.commands.packages")

describe("NuGet package commands", function()
  it("supports locked restore and lockfile creation", function()
    assert.are.same({ "dotnet", "restore", "App.csproj", "--locked-mode" }, packages.restore_cmd("App.csproj", "locked"))
    assert.are.same({ "dotnet", "restore", "App.csproj", "-p:RestorePackagesWithLockFile=true" }, packages.restore_cmd("App.csproj", "generate"))
  end)
  it("uses the SDK-appropriate list syntax", function()
    assert.are.same({
      "dotnet", "list", "App.csproj", "package", "--vulnerable", "--format", "json",
    }, packages.list_cmd("App.csproj", "vulnerable", 9))
    assert.are.same({
      "dotnet", "package", "list", "--project", "App.csproj", "--include-transitive", "--format", "json",
    }, packages.list_cmd("App.csproj", "transitive", 10))
  end)

  it("keeps package names and versions as separate arguments", function()
    assert.are.same({
      "dotnet", "add", "path with spaces/App.csproj", "package", "Some.Package", "--version", "2.0.0",
    }, packages.add_cmd("path with spaces/App.csproj", "Some.Package", "2.0.0"))
    assert.are.same({
      "dotnet", "remove", "App.csproj", "package", "Some.Package",
    }, packages.remove_cmd("App.csproj", "Some.Package"))
  end)
end)
