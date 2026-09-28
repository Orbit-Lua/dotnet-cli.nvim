local command = require("dotnet-cli.commands.workspace")
local project = require("dotnet-cli.project")

describe("workspace project picker", function()
  it("shows the picker before asynchronous discovery and icons on its rows", function()
    local original = project.get_csproj_files_async
    local scan_callback
    project.get_csproj_files_async = function(_, callback)
      scan_callback = callback
    end
    local workspace_options
    command.spec.action({
      append = function() end,
      select = function(_, items, opts)
        for _, item in ipairs(items) do
          assert.is_truthy(item.icon)
        end
        workspace_options = opts
      end,
    })
    local picker_items, updated_items
    local child = {
      select = function(_, items)
        picker_items = items
      end,
      update = function(_, items)
        updated_items = items
      end,
      clear = function() end,
      append = function() end,
    }
    workspace_options.on_select({ _raw = "project" }, child)
    assert.is_truthy(scan_callback)
    assert.is_truthy(picker_items)
    assert.is_nil(updated_items)
    scan_callback({ "App.csproj" })
    assert.are.equal(
      vim.fs.joinpath(require("dotnet-cli.workspace").current().root, "App.csproj"),
      updated_items[1]._raw
    )
    assert.is_truthy(updated_items[1].icon)
    project.get_csproj_files_async = original
  end)
end)
