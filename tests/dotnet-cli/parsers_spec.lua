local parsers = require("dotnet-cli.parsers")

describe("parsers", function()
  describe("templates", function()
    it("parses dotnet new list output", function()
      local lines = {
        "These templates matched your input:",
        "",
        "Template Name                                 Short Name       Language    Tags",
        "--------------------------------------------  ---------------  ----------  -------------------",
        "ASP.NET Core Empty                            web              [C#],F#     Web/Empty",
        "ASP.NET Core Web App (Model-View-Controller)  mvc              [C#],F#     Web/MVC",
        "Console App                                   console          [C#],F#,VB  Common/Console",
        "Class Library                                 classlib         [C#],F#,VB  Common/Library",
      }

      local result = parsers.templates(lines)

      assert.are.equal(4, #result)
      assert.are.equal("ASP.NET Core Empty", result[1].name)
      assert.are.equal("web", result[1].short_name)
      assert.are.equal("Console App", result[3].name)
      assert.are.equal("console", result[3].short_name)
    end)

    it("returns empty table for no templates", function()
      local lines = { "No templates found." }
      local result = parsers.templates(lines)
      assert.are.equal(0, #result)
    end)

    it("handles empty input", function()
      local result = parsers.templates({})
      assert.are.equal(0, #result)
    end)
  end)

  describe("sln_projects", function()
    it("parses dotnet sln list output", function()
      local lines = {
        "Project(s)",
        "----------",
        "src/MyApp/MyApp.csproj",
        "src/MyApp.Tests/MyApp.Tests.csproj",
      }

      local result = parsers.sln_projects(lines)

      assert.are.equal(2, #result)
      assert.are.equal("src/MyApp/MyApp.csproj", result[1])
      assert.are.equal("src/MyApp.Tests/MyApp.Tests.csproj", result[2])
    end)

    it("returns empty for no projects", function()
      local lines = {
        "Project(s)",
        "----------",
      }
      local result = parsers.sln_projects(lines)
      assert.are.equal(0, #result)
    end)

    it("handles multi-dash separators", function()
      local lines = {
        "Project(s)",
        "---------------------------------------------------",
        "WebApi.csproj",
      }
      local result = parsers.sln_projects(lines)
      assert.are.equal(1, #result)
      assert.are.equal("WebApi.csproj", result[1])
    end)
  end)

  describe("nuget_sources", function()
    it("parses nuget list source output", function()
      local lines = {
        "Registered Sources:",
        "  1.  nuget.org [Enabled]",
        "      https://api.nuget.org/v3/index.json",
        "  2.  myget [Disabled]",
        "      https://myget.org/feed/v3/index.json",
      }

      local result = parsers.nuget_sources(lines)

      assert.are.equal(2, #result)
      assert.are.equal("nuget.org", result[1].name)
      assert.are.equal("https://api.nuget.org/v3/index.json", result[1].url)
      assert.are.equal(true, result[1].enabled)
      assert.are.equal("myget", result[2].name)
      assert.are.equal(false, result[2].enabled)
    end)

    it("handles Chinese locale (已停用)", function()
      local lines = {
        "已註冊的來源:",
        "  1.  nuget.org [已停用]",
        "      https://api.nuget.org/v3/index.json",
      }

      local result = parsers.nuget_sources(lines)

      assert.are.equal(1, #result)
      assert.are.equal(false, result[1].enabled)
    end)

    it("handles Chinese locale (已禁用)", function()
      local lines = {
        "已注册的源:",
        "  1.  nuget.org [已禁用]",
        "      https://api.nuget.org/v3/index.json",
      }

      local result = parsers.nuget_sources(lines)

      assert.are.equal(1, #result)
      assert.are.equal(false, result[1].enabled)
    end)

    it("returns empty for no sources", function()
      local lines = { "Registered Sources:" }
      local result = parsers.nuget_sources(lines)
      assert.are.equal(0, #result)
    end)
  end)

  describe("sdk_versions", function()
    it("parses dotnet --list-sdks output", function()
      local lines = {
        "6.0.400 [/usr/share/dotnet/sdk]",
        "7.0.100 [/usr/share/dotnet/sdk]",
        "8.0.100 [/usr/share/dotnet/sdk]",
      }

      local result = parsers.sdk_versions(lines)

      assert.are.equal(3, #result)
      assert.are.equal("6.0.400", result[1])
      assert.are.equal("7.0.100", result[2])
      assert.are.equal("8.0.100", result[3])
    end)

    it("handles empty output", function()
      local result = parsers.sdk_versions({})
      assert.are.equal(0, #result)
    end)
  end)
end)
