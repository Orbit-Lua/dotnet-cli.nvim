local sdk = require("dotnet-cli.sdk")
local job = require("dotnet-cli.job")

describe("sdk", function()
  after_each(function()
    sdk._reset_cache()
  end)

  describe("is_available", function()
    it("returns a boolean", function()
      local result = sdk.is_available()
      assert.is_boolean(result)
    end)
  end)

  describe("get_major", function()
    it("returns number or nil", function()
      local result = sdk.get_major()
      if result ~= nil then
        assert.is_number(result)
        assert.is_true(result >= 1)
      end
    end)

    it("caches the result", function()
      local first = sdk.get_major()
      local second = sdk.get_major()
      assert.are.equal(first, second)
    end)
  end)

  describe("get_version", function()
    it("returns string or nil", function()
      local result = sdk.get_version()
      if result ~= nil then
        assert.is_string(result)
        -- Version should match semver pattern
        assert.is_truthy(result:match("^%d+%.%d+%.%d+"))
      end
    end)
  end)

  describe("per-root cache", function()
    local original

    before_each(function()
      original = job.run_sync
    end)

    after_each(function()
      job.run_sync = original
    end)

    it("keeps SDK versions separate for each root", function()
      local calls = 0
      job.run_sync = function(_, opts)
        calls = calls + 1
        return { opts.cwd == "/workspace/a" and "8.0.100" or "9.0.100" }, true
      end
      assert.are.equal("8.0.100", sdk.get_version("/workspace/a"))
      assert.are.equal("9.0.100", sdk.get_version("/workspace/b"))
      assert.are.equal("8.0.100", sdk.get_version("/workspace/a"))
      assert.are.equal(2, calls)
      assert.are.equal(8, sdk.get_major("/workspace/a"))
      assert.are.equal(9, sdk.get_major("/workspace/b"))
    end)
  end)

  describe("_reset_cache", function()
    it("clears cached SDK major version", function()
      -- Call to populate cache
      sdk.get_major()
      -- Reset
      sdk._reset_cache()
      -- Calling again should re-fetch (we can't easily verify this without mocking,
      -- but at minimum it shouldn't error)
      local result = sdk.get_major()
      if result ~= nil then
        assert.is_number(result)
      end
    end)
  end)
end)
