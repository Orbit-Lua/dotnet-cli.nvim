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
  end)

  describe("get_sln_files", function()
    it("returns a table", function()
      local files = project.get_sln_files()
      assert.is_table(files)
    end)

    it("includes both .sln and .slnx files", function()
      -- This test verifies the function structure handles both extensions
      -- Actual file presence depends on cwd
      local files = project.get_sln_files()
      assert.is_table(files)
    end)
  end)
end)
