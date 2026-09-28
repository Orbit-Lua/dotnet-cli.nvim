local diagnostics = require("dotnet-cli.commands.diagnostics")

describe(".NET diagnostics commands", function()
  it(
    "builds counters collection arguments with an explicit artifact path",
    function()
      assert.are.same(
        {
          "collect",
          "--process-id",
          "1234",
          "--format",
          "csv",
          "--output",
          "artifacts/diagnostics/counters.csv",
        },
        diagnostics.get_args(
          "counters",
          1234,
          "artifacts/diagnostics/counters.csv"
        )
      )
    end
  )

  it("builds trace and dump collection arguments", function()
    assert.are.same({
      "collect",
      "--process-id",
      "42",
      "--output",
      "trace file.nettrace",
    }, diagnostics.get_args("trace", 42, "trace file.nettrace"))
    assert.are.same({
      "collect",
      "--process-id",
      "42",
      "--output",
      "memory.dmp",
    }, diagnostics.get_args("dump", 42, "memory.dmp"))
  end)
end)
