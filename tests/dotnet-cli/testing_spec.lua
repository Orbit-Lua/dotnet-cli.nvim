local job = require("dotnet-cli.job")
local sdk = require("dotnet-cli.sdk")
local testing = require("dotnet-cli.commands.testing")

describe("testing command", function()
  local tmp
  local original_env
  local original_job
  local original_major

  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    original_env = vim.env.DOTNET_TEST_RUNNER
    original_job = job.run_sync
    original_major = sdk.get_major
    vim.env.DOTNET_TEST_RUNNER = nil
    sdk.get_major = function()
      return 10
    end
  end)

  after_each(function()
    vim.env.DOTNET_TEST_RUNNER = original_env
    job.run_sync = original_job
    sdk.get_major = original_major
    testing._reset_capabilities()
    vim.fn.delete(tmp, "rf")
  end)

  it("uses the nearest global.json runner setting", function()
    vim.fn.mkdir(vim.fs.joinpath(tmp, "src", "Tests"), "p")
    vim.fn.writefile(
      { vim.json.encode({ test = { runner = "Microsoft.Testing.Platform" } }) },
      vim.fs.joinpath(tmp, "global.json")
    )
    assert.are.equal(
      "mtp",
      testing.runner(vim.fs.joinpath(tmp, "src", "Tests"))
    )

    vim.fn.writefile(
      { vim.json.encode({ test = { runner = "VSTest" } }) },
      vim.fs.joinpath(tmp, "src", "global.json")
    )
    assert.are.equal(
      "vstest",
      testing.runner(vim.fs.joinpath(tmp, "src", "Tests"))
    )
  end)

  it("builds VSTest commands with framework filters and TRX output", function()
    local cmd = testing.command("Tests.csproj", "selected", {
      runner = "vstest",
      configuration = "Release",
      tfm = "net8.0",
      filter = "Tests.Sample.Run",
      results_dir = "results",
      trx_filename = "run.trx",
    })
    assert.are.same({
      "dotnet",
      "test",
      "Tests.csproj",
      "-c",
      "Release",
      "-f",
      "net8.0",
      "--filter",
      "FullyQualifiedName~Tests.Sample.Run",
      "--results-directory",
      "results",
      "--logger",
      "trx;LogFileName=run.trx",
    }, cmd)
  end)

  it(
    "uses native MTP options with SDK 10 and adds only advertised reports",
    function()
      local cmd = testing.command("Tests.csproj", "coverage", {
        runner = "mtp",
        sdk_major = 10,
        configuration = "Debug",
        results_dir = "results",
        capabilities = { trx = true },
      })
      assert.are.same({
        "dotnet",
        "test",
        "--project",
        "Tests.csproj",
        "-c",
        "Debug",
        "--results-directory",
        "results",
        "--coverage",
        "--report-trx",
      }, cmd)
    end
  )

  it("separates MTP arguments for SDK 9 bridge mode", function()
    local cmd = testing.command("Tests.csproj", "selected", {
      runner = "mtp",
      sdk_major = 9,
      filter = "Tests.Sample.Run",
    })
    assert.are.same({
      "dotnet",
      "test",
      "Tests.csproj",
      "--",
      "--filter",
      "FullyQualifiedName~Tests.Sample.Run",
    }, cmd)
  end)

  it("reports MTP capabilities from the project's help output", function()
    local calls = 0
    job.run_sync = function(cmd, opts)
      calls = calls + 1
      assert.are.equal(tmp, opts.cwd)
      assert.are.equal("--help", cmd[#cmd])
      return {
        "--list-tests",
        "--filter <EXPRESSION>",
        "--coverage",
        "--report-trx",
      },
        true
    end
    vim.fn.writefile(
      { vim.json.encode({ test = { runner = "Microsoft.Testing.Platform" } }) },
      vim.fs.joinpath(tmp, "global.json")
    )
    local caps = testing.capabilities("Tests.csproj", { root = tmp })
    assert.is_true(caps.discover)
    assert.is_true(caps.filter)
    assert.is_true(caps.coverage)
    assert.is_true(caps.trx)
    testing.capabilities("Tests.csproj", { root = tmp })
    assert.are.equal(1, calls)
  end)

  it("rejects MTP when the selected SDK is older than 10", function()
    sdk.get_major = function()
      return 9
    end
    vim.fn.writefile(
      { vim.json.encode({ test = { runner = "Microsoft.Testing.Platform" } }) },
      vim.fs.joinpath(tmp, "global.json")
    )
    local caps, err = testing.capabilities("Tests.csproj", { root = tmp })
    assert.is_nil(caps)
    assert.is_truthy(err:match("requires .NET SDK 10"))
  end)
end)
