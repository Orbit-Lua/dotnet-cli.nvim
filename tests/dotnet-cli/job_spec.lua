local job = require("dotnet-cli.job")

describe("job", function()
  describe("run_sync", function()
    it("returns lines and ok status for successful commands", function()
      local lines, ok = job.run_sync({ "echo", "hello" })
      assert.is_true(ok)
      assert.is_table(lines)
      assert.are.equal("hello", lines[1])
    end)

    it("returns lines and false for failed commands", function()
      local lines, ok = job.run_sync({ "false" })
      assert.is_false(ok)
      assert.is_table(lines)
    end)

    it("handles string commands", function()
      local lines, ok = job.run_sync("echo world")
      assert.is_true(ok)
      assert.are.equal("world", lines[1])
    end)
  end)

  describe("start", function()
    it("runs with a working directory and reports an exit status", function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, "p")
      local result
      local id = job.start({
        argv = { "sh", "-c", "pwd" },
        cwd = tmp,
        on_exit = function(code)
          result = code
        end,
      })
      assert.is_true(id > 0)
      assert.is_true(vim.wait(3000, function()
        return result ~= nil
      end, 10))
      assert.are.equal(0, result)
      vim.fn.delete(tmp, "rf")
    end)
  end)
end)
