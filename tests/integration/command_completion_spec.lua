local line = require("dotnet-cli.command_line")
local workspace = require("dotnet-cli.workspace")

describe("native SDK completion", function()
  local cwd
  before_each(function()
    cwd = vim.fn.getcwd()
    local root = vim.g.dotnet_test_root .. "/SDK completion"
    vim.fn.mkdir(root, "p")
    vim.fn.chdir(root)
    workspace.reset()
  end)
  after_each(function()
    vim.fn.chdir(cwd)
    workspace.reset()
  end)

  it(
    "completes at a UTF-16 cursor while returning byte replacement ranges",
    function()
      assert.equals(1, vim.fn.executable("dotnet"), "dotnet is required")
      local text = 'dotnet build "測試😀" --confi trailing'
      local cursor = #'dotnet build "測試😀" --confi'
      local result, error_message
      line.complete(
        workspace.current(),
        { text = text, cursor = cursor },
        function(items, err)
          result, error_message = items, err
        end
      )
      assert.is_true(vim.wait(10000, function()
        return result ~= nil
      end))
      assert.is_nil(error_message)
      local found
      for _, item in ipairs(result) do
        if item.label == "--configuration" then
          found = item
        end
      end
      assert.is_truthy(found)
      assert.equals("--configuration", found.text)
      assert.equals(#'dotnet build "測試😀" ', found.start)
      assert.equals(cursor, found.finish)
    end
  )
end)
