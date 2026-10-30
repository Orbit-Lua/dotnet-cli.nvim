describe("fresh editor workspace persistence", function()
  it(
    "restores isolated roots and refuses to replace a deleted saved application",
    function()
      local repository = vim.fn.getcwd()
      local root = vim.fs.normalize(vim.g.dotnet_test_root .. "/fresh process")
      local a, b = root .. "/first", root .. "/second"
      for _, path in ipairs({ a, b }) do
        vim.fn.mkdir(path, "p")
        vim.fn.writefile({}, path .. "/App.sln")
        vim.fn.writefile(
          {
            '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><OutputType>Exe</OutputType></PropertyGroup></Project>',
          },
          path .. "/App.csproj"
        )
      end
      local function child(path, mode, extra)
        local result = vim
          .system(
            {
              vim.v.progpath,
              "--headless",
              "--clean",
              "-i",
              "NONE",
              "-l",
              repository .. "/tests/fixtures/workspace_child.lua",
              repository,
              path,
              mode,
              extra or "",
            },
            {
              text = true,
              env = {
                XDG_CONFIG_HOME = root .. "/config",
                XDG_DATA_HOME = root .. "/data",
                XDG_STATE_HOME = root .. "/state",
                XDG_CACHE_HOME = root .. "/cache",
                NVIM_LOG_FILE = root .. "/child.log",
              },
            }
          )
          :wait(10000)
        assert.equals(0, result.code, result.stderr)
        return vim.json.decode(result.stdout)
      end
      child(a, "write", "Release")
      child(b, "write", "Debug")
      local first, second = child(a, "read"), child(b, "read")
      assert.equals(a .. "/App.csproj", first.project)
      assert.equals("Release", first.configuration)
      assert.equals("Development", first.profile)
      assert.equals("net10.0", first.tfm)
      assert.equals(b .. "/App.csproj", second.project)
      assert.equals("Debug", second.configuration)
      assert.equals(0, vim.fn.delete(a .. "/App.csproj"))
      vim.fn.writefile(
        {
          '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><OutputType>Exe</OutputType></PropertyGroup></Project>',
        },
        a .. "/Replacement.csproj"
      )
      local stopped =
        child(a, "debug", vim.g.dotnet_test_plugins .. "/nvim-dap")
      assert.equals(0, stopped.started)
      assert.is_truthy(stopped.message:find("missing", 1, true))
    end
  )
end)
