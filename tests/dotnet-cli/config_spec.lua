local config = require("dotnet-cli.config")

describe("config", function()
  before_each(function()
    -- Reset to defaults before each test
    config.setup({})
  end)

  it("has sensible defaults", function()
    local cfg = config.get()
    assert.are.equal(true, cfg.roslyn_auto_insert)
    assert.are.equal("Debug", cfg.default_build_config)
    assert.are.same({ "Debug", "Release" }, cfg.build_configurations)
    assert.are.equal("bin/{config}", cfg.output_dir_template)
  end)

  it("merges user options", function()
    config.setup({
      roslyn_auto_insert = false,
      default_build_config = "Release",
    })

    local cfg = config.get()
    assert.are.equal(false, cfg.roslyn_auto_insert)
    assert.are.equal("Release", cfg.default_build_config)
    -- Unset options keep defaults
    assert.are.same({ "Debug", "Release" }, cfg.build_configurations)
  end)

  it("handles nil opts gracefully", function()
    config.setup(nil)
    local cfg = config.get()
    assert.are.equal(true, cfg.roslyn_auto_insert)
  end)

  it("deep extends nested tables", function()
    config.setup({
      build_configurations = { "Debug", "Release", "Staging" },
    })

    local cfg = config.get()
    assert.are.same({ "Debug", "Release", "Staging" }, cfg.build_configurations)
  end)
end)
