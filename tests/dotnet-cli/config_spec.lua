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
    assert.is_nil(cfg.output_dir_template)
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

  it("replaces a default list instead of merging it by index", function()
    config.setup({ build_configurations = { "Release" } })
    assert.are.same({ "Release" }, config.get().build_configurations)
  end)

  it("rejects unknown keys and wrong types by their option path", function()
    config.setup({ default_build_config = "Release" })
    local cases = {
      { { dap = { integrated_consol = false } }, "dap.integrated_consol: unknown option" },
      { { roslyn = true }, "roslyn: unknown option" },
      { { nuget = { allow_insecure_connections = "yes" } }, "nuget.allow_insecure_connections: expected boolean, got string" },
      { { build_configurations = { "Debug", 1 } }, "build_configurations: expected string[], got table" },
      { { dap = true }, "dap: expected table, got boolean" },
      { "Debug", "dotnet-cli options: expected table, got string" },
    }
    for _, case in ipairs(cases) do
      local ok, err = pcall(config.setup, case[1])
      assert.is_false(ok)
      assert.are.equal(case[2], err)
    end
    assert.are.equal("Release", config.get().default_build_config)
  end)

  it("rejects invalid options before setup registers commands", function()
    pcall(vim.api.nvim_del_user_command, "DotnetManager")
    local ok, err = pcall(require("dotnet-cli").setup, { dap = { nope = 1 } })
    assert.is_false(ok)
    assert.are.equal("dap.nope: unknown option", err)
    assert.is_nil(vim.api.nvim_get_commands({}).DotnetManager)
  end)

  it("rejects unknown and mistyped debug adapter options", function()
    package.loaded.dap = { adapters = {}, configurations = {} }
    local dap = require("dotnet-cli.dap")
    local ok, err = dap.setup({ adapter = "x" })
    assert.is_false(ok)
    assert.are.equal("adapter: unknown option", err)
    ok, err = dap.setup({ adapter_path = 1 })
    assert.is_false(ok)
    assert.are.equal("adapter_path: expected string, got number", err)
    package.loaded.dap = nil
  end)
end)
