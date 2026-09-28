local launch = require("dotnet-cli.launch")

describe("launch", function()
  local tmp

  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(vim.fs.joinpath(tmp, "Properties"), "p")
  end)

  after_each(function()
    vim.fn.delete(tmp, "rf")
  end)

  it(
    "returns sorted Project profiles and resolves working directories",
    function()
      local settings = {
        profiles = {
          Browser = { commandName = "IISExpress" },
          Zeta = { commandName = "Project", workingDirectory = "run" },
          Alpha = {
            commandName = "Project",
            applicationUrl = "http://localhost:5000",
          },
        },
      }
      vim.fn.writefile(
        { vim.json.encode(settings) },
        vim.fs.joinpath(tmp, "Properties", "launchSettings.json")
      )
      local profiles = launch.profiles(vim.fs.joinpath(tmp, "A.csproj"))
      assert.are.equal(2, #profiles)
      assert.are.equal("Alpha", profiles[1].name)
      assert.are.equal(vim.fs.normalize(tmp), profiles[1].workingDirectory)
      assert.are.equal(
        vim.fs.normalize(vim.fs.joinpath(tmp, "run")),
        profiles[2].workingDirectory
      )
    end
  )

  it("returns an empty list when settings are absent", function()
    assert.are.same({}, launch.profiles(vim.fs.joinpath(tmp, "A.csproj")))
  end)
end)
