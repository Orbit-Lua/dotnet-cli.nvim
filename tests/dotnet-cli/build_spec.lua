local build = require("dotnet-cli.commands.build")
local config = require("dotnet-cli.config")

describe("build command", function()
  before_each(function()
    config.setup({})
  end)

  it("uses the configured default build configuration", function()
    config.setup({
      default_build_config = "Release",
    })

    local cmd = build.get_cmd("src/App/App.csproj")

    assert.are.same({
      "dotnet",
      "build",
      "src/App/App.csproj",
      "-c",
      "Release",
      "-o",
      vim.fs.joinpath(vim.fn.getcwd(), "bin", "Release"),
    }, cmd)
  end)

  it("uses the configured output directory template", function()
    config.setup({
      output_dir_template = "artifacts/{config}",
    })

    local cmd = build.get_cmd("src/App/App.csproj", "Debug")

    assert.are.same(
      vim.fs.joinpath(vim.fn.getcwd(), "artifacts", "Debug"),
      cmd[#cmd]
    )
  end)

  it("uses configured build configurations in the manager", function()
    config.setup({
      build_configurations = { "Debug", "Release", "Staging" },
    })

    local items
    build.spec.action({
      select = function(_, selected_items)
        items = selected_items
      end,
    })

    assert.are.same("Debug", items[1]._raw)
    assert.are.same("Release", items[2]._raw)
    assert.are.same("Staging", items[3]._raw)
  end)
end)
