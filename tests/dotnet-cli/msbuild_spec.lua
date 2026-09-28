local job = require("dotnet-cli.job")
local msbuild = require("dotnet-cli.msbuild")

describe("msbuild", function()
  local original

  before_each(function()
    original = job.run_sync
  end)

  after_each(function()
    job.run_sync = original
  end)

  it("returns evaluated target path and output type", function()
    job.run_sync = function(cmd)
      assert.are.equal("-property:Configuration=Release", cmd[#cmd - 1])
      assert.are.equal("-property:TargetFramework=net8.0", cmd[#cmd])
      return {
        '{"Properties":{"TargetPath":"bin/Release/net8.0/A.dll",',
        '"OutputType":"Exe","TargetFramework":"net8.0",',
        '"TargetFrameworks":"net8.0;net9.0"}}',
      },
        true
    end
    local data, err = msbuild.get("A.csproj", "Release", "net8.0")
    assert.is_nil(err)
    assert.are.equal(
      vim.fs.normalize(vim.fn.getcwd() .. "/bin/Release/net8.0/A.dll"),
      data.TargetPath
    )
    assert.are.equal("Exe", data.OutputType)
    assert.are.equal("net8.0;net9.0", data.TargetFrameworks)
  end)

  it("reports failed queries without guessing a target path", function()
    job.run_sync = function()
      return { "unsupported option" }, false
    end
    local data, err = msbuild.get("A.csproj")
    assert.is_nil(data)
    assert.is_truthy(err:match("metadata query failed"))
  end)
end)
