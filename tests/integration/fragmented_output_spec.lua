local job = require("dotnet-cli.job")
local workspace = require("dotnet-cli.workspace")

describe("fragmented native output", function()
  local start, cwd, root
  before_each(function()
    start, cwd = job.start, vim.fn.getcwd()
    local fixture = cwd .. "/tests/fixtures/process.lua"
    root = vim.fs.normalize(vim.g.dotnet_test_root .. "/fragmented")
    vim.fn.mkdir(root, "p")
    vim.fn.chdir(root)
    workspace.reset()
    job.start = function(spec, ctx)
      local mode = spec.argv[2] == "complete" and "completion-chunks"
        or "json-chunks"
      spec.argv = {
        vim.v.progpath,
        "--headless",
        "--clean",
        "-i",
        "NONE",
        "-l",
        fixture,
        mode,
      }
      return start(spec, ctx)
    end
  end)
  after_each(function()
    job.start = start
    vim.fn.chdir(cwd)
    workspace.reset()
  end)
  it(
    "parses metadata when a JSON string spans native stdout callbacks",
    function()
      local data, error_message, finished
      require("dotnet-cli.msbuild").get_async(
        root .. "/App.csproj",
        "Debug",
        nil,
        root,
        function(value, err)
          data, error_message, finished = value, err, true
        end
      )
      assert.is_true(vim.wait(5000, function()
        return finished
      end))
      assert.is_nil(error_message)
      assert.equals(root .. "/App.dll", data.TargetPath)
    end
  )
  it("does not split one SDK completion into separate candidates", function()
    local items
    require("dotnet-cli.command_line").complete(
      workspace.current(),
      { text = "dotnet bu", cursor = 9 },
      function(value)
        items = value
      end
    )
    assert.is_true(vim.wait(5000, function()
      return items ~= nil
    end))
    assert.equals(1, #items)
    assert.equals("build", items[1].text)
  end)
end)
