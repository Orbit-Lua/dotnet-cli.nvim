local sdk = require("dotnet-cli.sdk")

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
