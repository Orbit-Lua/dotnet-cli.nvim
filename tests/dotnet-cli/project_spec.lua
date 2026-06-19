local project = require("dotnet-cli.project")

describe("project", function()
  describe("get_file_icon", function()
    it("returns a string with trailing space", function()
      local icon = project.get_file_icon("MyApp.csproj")
      assert.is_string(icon)
      -- Should end with a space for alignment
      assert.is_truthy(icon:match("%s$"))
    end)

    it("uses fallback when devicons unavailable", function()
      -- Since we're in minimal mode, devicons may not be loaded
      local icon = project.get_file_icon("test.xyz")
      assert.is_string(icon)
      assert.is_truthy(#icon > 0)
    end)
  end)

  describe("get_csproj_files", function()
    it("returns a table", function()
      local files = project.get_csproj_files()
      assert.is_table(files)
    end)

    it("finds projects recursively", function()
      local cwd = vim.fn.getcwd()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(vim.fs.joinpath(tmp, "src", "App"), "p")
      vim.fn.writefile({}, vim.fs.joinpath(tmp, "Root.csproj"))
      vim.fn.writefile({}, vim.fs.joinpath(tmp, "src", "App", "App.csproj"))

      vim.cmd("cd " .. vim.fn.fnameescape(tmp))
      local files = project.get_csproj_files()
      vim.cmd("cd " .. vim.fn.fnameescape(cwd))
      vim.fn.delete(tmp, "rf")

      assert.are.same({ "Root.csproj", "src/App/App.csproj" }, files)
    end)
  end)

  describe("get_sln_files", function()
    it("returns a table", function()
      local files = project.get_sln_files()
      assert.is_table(files)
    end)

    it("includes both .sln and .slnx files", function()
      local cwd = vim.fn.getcwd()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(vim.fs.joinpath(tmp, "nested"), "p")
      vim.fn.writefile({}, vim.fs.joinpath(tmp, "Root.sln"))
      vim.fn.writefile({}, vim.fs.joinpath(tmp, "nested", "Next.slnx"))

      vim.cmd("cd " .. vim.fn.fnameescape(tmp))
      local files = project.get_sln_files()
      vim.cmd("cd " .. vim.fn.fnameescape(cwd))
      vim.fn.delete(tmp, "rf")

      assert.are.same({ "Root.sln", "nested/Next.slnx" }, files)
    end)
  end)
end)
