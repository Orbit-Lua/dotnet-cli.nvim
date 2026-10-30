local line = require("dotnet-cli.command_line")
local workspace = require("dotnet-cli.workspace")
local job = require("dotnet-cli.job")
local comet = require("comet")
local state = require("comet.state")
local action = require("comet.action")
local window = require("comet.ui.window")

describe("dotnet command entry", function()
  local saved, root, commands
  before_each(function()
    root = vim.fs.normalize(vim.g.dotnet_test_root .. "/command workspace")
    vim.fn.mkdir(root, "p")
    vim.fn.writefile({}, root .. "/App.sln")
    vim.fn.writefile({}, root .. "/App.csproj")
    saved =
      { cwd = vim.fn.getcwd(), jobstart = vim.fn.jobstart, cancel = job.cancel }
    vim.fn.chdir(root)
    workspace.reset()
    workspace.select_project(root .. "/App.csproj")
    workspace.set({ configuration = "Release", tfm = "net10.0" })
    commands = {}
    vim.fn.jobstart = function(argv, options)
      commands[#commands + 1] = { argv = argv, cwd = options.cwd }
      local id = #commands
      vim.schedule(function()
        options.on_stdout(
          id,
          argv[2] == "complete" and { "build", "--configuration", "" }
            or { "SDK operation complete", "" },
          "stdout"
        )
        options.on_exit(id, 0, "exit")
      end)
      return id
    end
    job.cancel = function() end
    comet.open({ line.spec }, { session_id = root, insert_mode = false })
    action.run_selected()
  end)
  after_each(function()
    window.close()
    vim.fn.jobstart, job.cancel = saved.jobstart, saved.cancel
    vim.fn.chdir(saved.cwd)
    workspace.reset()
    for _, buffer in pairs(state.output_buf_cache) do
      if vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
    state.output_buf_cache, state.persisted_states, state.running_tasks =
      {}, {}, {}
    vim.fn.delete(root, "rf")
    vim.fn.delete(vim.fn.stdpath("state") .. "/dotnet-cli", "rf")
  end)
  local function input(text)
    local S = state.get()
    vim.api.nvim_buf_set_lines(S.input_buf, 0, -1, false, { S.prompt .. text })
    vim.api.nvim_win_set_cursor(S.input_win, { 1, #S.prompt + #text })
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = S.input_buf })
  end

  it("preserves empty arguments, quoted paths, and UNC separators", function()
    local argv = assert(
      line.parse([[dotnet run -- "" "C:\my app\App.dll" '\\server\share\']])
    )
    assert.same(
      { "dotnet", "run", "--", "", [[C:\my app\App.dll]], [[\\server\share\]] },
      argv
    )
    assert.is_nil(line.parse([[dotnet build "unfinished]]))
  end)

  it(
    "executes the captured project and configuration without echoing the command",
    function()
      input("dotnet build")
      action.run_selected()
      assert.equals(1, #commands)
      local argv = commands[1].argv
      assert.equals(root, commands[1].cwd)
      assert.equals(root .. "/App.csproj", argv[3])
      assert.equals("Release", argv[5])
      assert.is_true(vim.wait(500, function()
        return table
          .concat(
            vim.api.nvim_buf_get_lines(state.get().output_buf, 0, -1, false),
            "\n"
          )
          :find("SDK operation complete", 1, true) ~= nil
      end))
      local text = table.concat(
        vim.api.nvim_buf_get_lines(state.get().output_buf, 0, -1, false),
        "\n"
      )
      assert.is_nil(text:find("dotnet build", 1, true))
      assert.is_truthy(text:find("SDK operation complete", 1, true))
    end
  )

  it(
    "does not add another project when an explicit project follows options",
    function()
      input("dotnet build --configuration=Debug Other.csproj")
      action.run_selected()
      assert.is_false(vim.tbl_contains(commands[1].argv, root .. "/App.csproj"))
      assert.is_false(vim.tbl_contains(commands[1].argv, "Release"))
    end
  )

  it(
    "rejects positional and option credentials before completion or execution",
    function()
      for _, text in ipairs({
        [[dotnet ef dbcontext scaffold "Server=local;Password=SENTINEL" Microsoft.EntityFrameworkCore.SqlServer]],
        [[dotnet nuget push App.nupkg --api-key SENTINEL]],
        [[dotnet user-secrets set Key SENTINEL]],
        [[dotnet build -p:Password=SENTINEL]],
      }) do
        input(text)
        vim.wait(120, function()
          return false
        end)
        action.run_selected()
        assert.equals(0, #commands)
        assert.is_nil(
          vim.inspect(state.persisted_states):find("SENTINEL", 1, true)
        )
        local output = table.concat(
          vim.api.nvim_buf_get_lines(state.get().output_buf, 0, -1, false),
          "\n"
        )
        assert.is_nil(output:find("SENTINEL", 1, true))
        assert.is_nil(
          vim.api
            .nvim_buf_get_lines(state.get().input_buf, 0, 1, false)[1]
            :find("SENTINEL", 1, true)
        )
      end
    end
  )

  it(
    "uses UTF-16 completion positions with UTF-8 replacement ranges",
    function()
      local text = 'dotnet build "測試😀" --confi trailing'
      local cursor = #'dotnet build "測試😀" --confi'
      local items
      line.complete(
        workspace.current(),
        { text = text, cursor = cursor },
        function(result)
          items = result
        end
      )
      assert.is_true(vim.wait(500, function()
        return items ~= nil
      end))
      assert.equals("27", commands[1].argv[4])
      assert.equals(#'dotnet build "測試😀" ', items[2].start)
      assert.equals(cursor, items[2].finish)
    end
  )

  it("aborts submission after workspace selection changes", function()
    workspace.set({ configuration = "Debug" })
    input("dotnet build")
    action.run_selected()
    assert.equals(0, #commands)
  end)

  it("inserts SDK defaults before application arguments", function()
    input("dotnet run -- hello --configuration=AppValue")
    action.run_selected()
    local argv = commands[1].argv
    local separator
    for i, value in ipairs(argv) do
      if value == "--" then
        separator = i
      end
    end
    assert.is_truthy(separator)
    assert.same(
      { "hello", "--configuration=AppValue" },
      vim.list_slice(argv, separator + 1)
    )
    assert.is_true(
      vim.tbl_contains(
        vim.list_slice(argv, 1, separator - 1),
        root .. "/App.csproj"
      )
    )
    assert.is_true(
      vim.tbl_contains(vim.list_slice(argv, 1, separator - 1), "Release")
    )
  end)

  it("preserves explicit directory operands after SDK options", function()
    input("dotnet build --configuration Debug ./src/App")
    action.run_selected()
    assert.is_true(vim.tbl_contains(commands[1].argv, "./src/App"))
    assert.is_false(vim.tbl_contains(commands[1].argv, root .. "/App.csproj"))
  end)

  it("allows project names containing a credential-related word", function()
    input("dotnet build PasswordChecks.csproj")
    action.run_selected()
    assert.equals(1, #commands)
    assert.is_true(vim.tbl_contains(commands[1].argv, "PasswordChecks.csproj"))
  end)
end)
