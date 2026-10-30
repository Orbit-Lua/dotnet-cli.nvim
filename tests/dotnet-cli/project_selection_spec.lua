local workspace = require("dotnet-cli.workspace")
local project = require("dotnet-cli.project")
local comet = require("comet")
local state = require("comet.state")
local action = require("comet.action")
local window = require("comet.ui.window")

describe("manager project selection ownership", function()
  local root, saved, finish, selected
  before_each(function()
    root = vim.fs.normalize(vim.g.dotnet_test_root .. "/project picker")
    for _, name in ipairs({ "first", "second" }) do
      vim.fn.mkdir(root .. "/" .. name, "p")
      vim.fn.writefile({}, root .. "/" .. name .. "/App.sln")
      vim.fn.writefile({}, root .. "/" .. name .. "/App.csproj")
    end
    saved = {
      cwd = vim.fn.getcwd(),
      scan = project.get_csproj_files_async,
      run = require("dotnet-cli.job").run,
      select = vim.ui.select,
      notify = vim.notify,
    }
    vim.fn.chdir(root .. "/first")
    workspace.reset()
    project.get_csproj_files_async = function(path, callback)
      assert.equals(root .. "/first", path)
      finish = callback
    end
    comet.open({
      {
        name = "Select",
        action = function(ctx)
          project.select_csproj(ctx, function(path)
            selected = path
          end)
        end,
      },
    }, { insert_mode = false })
    action.run_selected()
  end)
  after_each(function()
    require("dotnet-cli.job").run, vim.ui.select, vim.notify =
      saved.run, saved.select, saved.notify
    window.close()
    project.get_csproj_files_async = saved.scan
    vim.fn.chdir(saved.cwd)
    workspace.reset()
    vim.fn.delete(root, "rf")
    vim.fn.delete(vim.fn.stdpath("state") .. "/dotnet-cli", "rf")
    for _, buffer in pairs(state.output_buf_cache) do
      if vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
    state.output_buf_cache, state.persisted_states = {}, {}
    selected = nil
  end)
  it("returns absolute paths from the captured workspace", function()
    finish({ "App.csproj" })
    assert.equals(root .. "/first/App.csproj", selected)
  end)
  it("rejects a late single result after changing workspaces", function()
    vim.fn.chdir(root .. "/second")
    workspace.activate(root .. "/second")
    finish({ "App.csproj" })
    assert.is_nil(selected)
    assert.is_nil(workspace.current().project)
  end)

  it(
    "rejects deferred public Build and Publish selections after switching roots",
    function()
      window.close()
      local calls = 0
      require("dotnet-cli.job").run = function()
        calls = calls + 1
      end
      vim.notify = function() end
      require("dotnet-cli.commands.register").setup("Dotnet")
      for _, name in ipairs({ "DotnetBuild", "DotnetPublish" }) do
        vim.fn.chdir(root .. "/first")
        workspace.activate(root .. "/first")
        local choose
        vim.ui.select = function(_, _, callback)
          choose = callback
        end
        vim.cmd(name)
        finish({ "App.csproj" })
        assert.is_function(choose)
        vim.fn.chdir(root .. "/second")
        workspace.activate(root .. "/second")
        choose("App.csproj")
      end
      assert.equals(0, calls)
    end
  )

  it(
    "keeps the manager Build configuration submenu bound to its original root",
    function()
      window.close()
      local calls = 0
      require("dotnet-cli.job").run = function()
        calls = calls + 1
      end
      comet.open({ require("dotnet-cli.commands.build").spec }, {
        session_id = "dotnet_manager:" .. root .. "/first",
        insert_mode = false,
      })
      action.run_selected()
      workspace.select_project(root .. "/second/App.csproj")
      action.run_selected()
      assert.equals(0, calls)
      assert.equals("Debug", workspace.current().configuration)
      assert.equals(root .. "/second/App.csproj", workspace.current().project)
    end
  )

  it(
    "clears the old framework when public Build chooses another project",
    function()
      window.close()
      workspace.select_project(
        root .. "/first/Other.csproj",
        { tfm = "net9.0" }
      )
      local executed
      require("dotnet-cli.job").run = function(argv, _, _, opts)
        executed = { argv = argv, cwd = opts.cwd }
      end
      vim.notify = function() end
      vim.ui.select = function(_, _, callback)
        callback("App.csproj")
      end
      require("dotnet-cli.commands.register").setup("Dotnet")
      vim.cmd("DotnetBuild")
      finish({ "App.csproj" })
      assert.is_truthy(executed)
      assert.equals(root .. "/first", executed.cwd)
      assert.is_false(vim.tbl_contains(executed.argv, "net9.0"))
      assert.is_nil(workspace.current().tfm)
    end
  )

  it(
    "keeps an unchanged manager Build submenu usable after reopening",
    function()
      window.close()
      workspace.select_project(root .. "/first/App.csproj")
      local executed
      require("dotnet-cli.job").run = function(argv)
        executed = argv
      end
      local commands = { require("dotnet-cli.commands.build").spec }
      local opts = {
        session_id = "dotnet_manager:" .. root .. "/first",
        insert_mode = false,
      }
      comet.open(commands, opts)
      action.run_selected()
      window.close()
      comet.open(commands, opts)
      action.run_selected()
      assert.is_truthy(executed)
      assert.equals(root .. "/first/App.csproj", executed[3])
    end
  )

  it(
    "preserves a solutionless workspace root when selecting a nested project",
    function()
      window.close()
      local solutionless = root .. "/solutionless"
      vim.fn.mkdir(solutionless .. "/src/App", "p")
      vim.fn.writefile({}, solutionless .. "/src/App/App.csproj")
      vim.fn.chdir(solutionless)
      workspace.activate(solutionless)
      workspace.set({ configuration = "Release" })
      project.get_csproj_files_async = function(_, callback)
        callback({ "src/App/App.csproj" })
      end
      local executed
      require("dotnet-cli.job").run = function(argv, _, _, opts)
        executed = { argv = argv, cwd = opts.cwd }
      end
      comet.open({ require("dotnet-cli.commands.run").spec }, {
        session_id = "dotnet_manager:" .. solutionless,
        insert_mode = false,
      })
      action.run_selected()
      assert.is_truthy(executed)
      assert.equals(solutionless, executed.cwd)
      assert.equals(solutionless, workspace.current().root)
      assert.equals("Release", workspace.current().configuration)
    end
  )

  it(
    "restores explicit Startup Project choices at a solutionless parent root",
    function()
      window.close()
      local parent = root .. "/explicit-parent"
      vim.fn.mkdir(parent .. "/src/App", "p")
      vim.fn.writefile({}, parent .. "/src/App/App.csproj")
      vim.fn.chdir(parent)
      workspace.activate(parent)
      project.get_csproj_files_async = function(_, callback)
        callback({ "src/App/App.csproj" })
      end
      comet.open({ require("dotnet-cli.commands.workspace").spec }, {
        session_id = "dotnet_manager:" .. parent,
        insert_mode = false,
      })
      action.run_selected()
      action.run_selected()
      action.run_selected()
      assert.equals(parent, workspace.current().root)
      assert.equals(
        parent .. "/src/App/App.csproj",
        workspace.current().project
      )
      window.close()
      workspace.reset()
      assert.equals(
        parent .. "/src/App/App.csproj",
        workspace.activate(parent).project
      )
    end
  )
end)
